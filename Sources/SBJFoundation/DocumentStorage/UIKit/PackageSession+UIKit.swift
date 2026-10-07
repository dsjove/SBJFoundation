#if canImport(UIKit) && !os(tvOS) && !os(watchOS)
import Foundation
import UIKit

/// Active lifecycle for one package-backed file on UIKit platforms.
///
/// `UIDocument` owns coordinated access, autosaving, file presentation and
/// version-conflict tracking. Clients interact only with this platform-neutral
/// API and do not need to know that UIKit is the backend.
final class PackageSession<Document: PackageDocument>: UIDocument, @unchecked Sendable {
	typealias Snapshot = Document.Snapshot

	private struct SaveContext: Sendable {
		let change: Int
		let operation: PackagePersistenceOperation
	}

	private final class SavePayload: NSObject {
		let context: SaveContext
		let snapshot: Snapshot

		init(context: SaveContext, snapshot: Snapshot) {
			self.context = context
			self.snapshot = snapshot
		}
	}

	private let stateLock = NSLock()
	private var storedState: Snapshot
	private var suppressNextLoadedEvent = false
	private var changeSequence = 0
	private var persistedChangeSequence = 0
	private var requestedSaveOperation: PackagePersistenceOperation?
	private var activeSaveContext: SaveContext?
	private var recentSaveFailure: (domain: String, code: Int, message: String, at: Date)?
	private let eventLock = NSLock()
	private var eventDeliveryTask: Task<Void, Never>?
	@MainActor private var explicitSaveTask: Task<Void, Error>?
	@MainActor private var explicitSaveRequestedAgain = false
	private let onEvent: @MainActor @Sendable (PackageSessionEvent<Snapshot>) async -> Void

	var state: Snapshot {
		stateLock.withLock { storedState }
	}

	var currentChange: Int {
		stateLock.withLock { changeSequence }
	}

	var lastPersistedChange: Int {
		stateLock.withLock { persistedChangeSequence }
	}

	init(
		fileURL: URL,
		state: Snapshot,
		onEvent: @escaping @MainActor @Sendable (PackageSessionEvent<Snapshot>) async -> Void
	) {
		self.storedState = state
		self.onEvent = onEvent
		super.init(fileURL: fileURL)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(documentStateDidChange(_:)),
			name: UIDocument.stateChangedNotification,
			object: self
		)
	}

	@objc private func documentStateDidChange(_ notification: Notification) {
		guard documentState.contains(.inConflict) else { return }
		emit(.conflict)
	}

	override func contents(forType typeName: String) throws -> Any {
		let (context, snapshot) = stateLock.withLock { () -> (SaveContext, Snapshot) in
			let context = SaveContext(
				change: changeSequence,
				operation: requestedSaveOperation ?? .autosave
			)
			requestedSaveOperation = nil
			activeSaveContext = context
			return (context, storedState)
		}
		emit(.saveStarted(change: context.change, operation: context.operation))
		return SavePayload(context: context, snapshot: snapshot)
	}

	override func writeContents(
		_ contents: Any,
		to url: URL,
		for saveOperation: UIDocument.SaveOperation,
		originalContentsURL: URL?
	) throws {
		guard let payload = contents as? SavePayload else {
			throw CocoaError(.fileWriteUnknown)
		}
		do {
			let warnings = try Document.persist(payload.snapshot, to: url)
			for warning in warnings { emit(.warning(warning)) }
		} catch {
			recordSaveFailure(error, context: payload.context)
			throw error
		}

		let context = stateLock.withLock { () -> SaveContext? in
			defer { activeSaveContext = nil }
			if activeSaveContext?.change == payload.context.change,
				activeSaveContext?.operation == payload.context.operation {
				persistedChangeSequence = max(persistedChangeSequence, payload.context.change)
				return activeSaveContext
			}
			return nil
		}
		if let context {
			emit(.saveSucceeded(change: context.change, operation: context.operation, at: .now))
		}
	}

	override func load(fromContents contents: Any, ofType typeName: String?) throws {
		guard let wrapper = contents as? FileWrapper else { throw CocoaError(.fileReadCorruptFile) }
		let loaded = try Document.snapshot(from: wrapper, at: fileURL)
		let shouldEmit = stateLock.withLock { () -> Bool in
			storedState = loaded
			if suppressNextLoadedEvent {
				suppressNextLoadedEvent = false
				return false
			}
			return true
		}
		if shouldEmit { emit(.loaded(loaded)) }
	}

	override func presentedItemDidMove(to newURL: URL) {
		super.presentedItemDidMove(to: newURL)
		emit(.moved(newURL))
	}

	override func accommodatePresentedItemDeletion(
		completionHandler: @escaping @Sendable (Error?) -> Void
	) {
		emit(.deleted)
		super.accommodatePresentedItemDeletion(completionHandler: completionHandler)
	}

	override func handleError(_ error: any Error, userInteractionPermitted: Bool) {
		if let context = stateLock.withLock({ activeSaveContext }) {
			recordSaveFailure(error, context: context)
		} else if !consumeMatchingRecentSaveFailure(error) {
			emit(.error(error))
		}
		super.handleError(error, userInteractionPermitted: userInteractionPermitted)
	}

	private func consumeMatchingRecentSaveFailure(_ error: Error) -> Bool {
		let nsError = error as NSError
		return stateLock.withLock {
			guard let recentSaveFailure,
				Date().timeIntervalSince(recentSaveFailure.at) < 2,
				recentSaveFailure.domain == nsError.domain,
				recentSaveFailure.code == nsError.code,
				recentSaveFailure.message == error.localizedDescription
			else { return false }
			self.recentSaveFailure = nil
			return true
		}
	}

	private func recordSaveFailure(_ error: Error, context: SaveContext) {
		let shouldEmit = stateLock.withLock { () -> Bool in
			guard activeSaveContext?.change == context.change,
				activeSaveContext?.operation == context.operation
			else { return false }
			activeSaveContext = nil
			return true
		}
		guard shouldEmit else { return }
		let failure = PackagePersistenceFailure(error: error, operation: context.operation, fileURL: fileURL)
		let nsError = error as NSError
		stateLock.withLock {
			recentSaveFailure = (nsError.domain, nsError.code, error.localizedDescription, .now)
		}
		emit(.saveFailed(change: context.change, failure: failure))
	}

	private func emit(_ event: PackageSessionEvent<Snapshot>) {
		let task = eventLock.withLock { () -> Task<Void, Never> in
			let previous = eventDeliveryTask
			let task = Task { @MainActor [onEvent] in
				if let previous { await previous.value }
				await onEvent(event)
			}
			eventDeliveryTask = task
			return task
		}
		_ = task
	}

	@MainActor
	@discardableResult
	func replaceState(_ state: Snapshot) -> Int {
		let change = stateLock.withLock { () -> Int in
			storedState = state
			changeSequence &+= 1
			return changeSequence
		}
		updateChangeCount(.done)
		return change
	}

	@MainActor
	func discardUnsavedChanges() {
		updateChangeCount(.cleared)
	}

	@MainActor
	func openSession(suppressingInitialLoadEvent: Bool = false) async throws {
		stateLock.withLock { suppressNextLoadedEvent = suppressingInitialLoadEvent }
		do {
			try await withCheckedThrowingContinuation { continuation in
				open { success in
					if success { continuation.resume() }
					else { continuation.resume(throwing: CocoaError(.fileReadUnknown)) }
				}
			}
		} catch {
			stateLock.withLock { suppressNextLoadedEvent = false }
			throw error
		}
	}

	@MainActor
	func createSession() async throws {
		stateLock.withLock { requestedSaveOperation = .create }
		do {
			try await withCheckedThrowingContinuation { continuation in
				save(to: fileURL, for: .forCreating) { success in
					if success { continuation.resume() }
					else { continuation.resume(throwing: CocoaError(.fileWriteUnknown)) }
				}
			}
		} catch {
			failPendingSaveIfNeeded(error, fallbackOperation: .create)
			throw error
		}
	}

	@MainActor
	func saveNow(operation: PackagePersistenceOperation = .explicitSave) async throws {
		let targetChange = currentChange
		guard targetChange > lastPersistedChange else { return }

		if let explicitSaveTask {
			explicitSaveRequestedAgain = true
			try await explicitSaveTask.value
			if lastPersistedChange >= targetChange { return }
		}

		let task = Task { @MainActor [weak self] in
			guard let self else { return }
			repeat {
				self.explicitSaveRequestedAgain = false
				try await self.performSaveNow(operation: operation)
			} while self.explicitSaveRequestedAgain && self.currentChange > self.lastPersistedChange
		}
		explicitSaveTask = task
		defer {
			explicitSaveTask = nil
			explicitSaveRequestedAgain = false
		}
		try await task.value

		guard lastPersistedChange >= targetChange else {
			throw CocoaError(.fileWriteUnknown)
		}
	}

	@MainActor
	private func performSaveNow(operation: PackagePersistenceOperation) async throws {
		guard currentChange > lastPersistedChange else { return }

		// `UIDocument.hasUnsavedChanges` can become false while an autosave is
		// already being committed. Our revision counters are the authoritative
		// barrier state, so make sure UIKit has a change to flush whenever the
		// requested revision is not yet known to be durable.
		if !hasUnsavedChanges {
			updateChangeCount(.done)
		}
		stateLock.withLock { requestedSaveOperation = operation }
		do {
			try await withCheckedThrowingContinuation { continuation in
				autosave { success in
					if success { continuation.resume() }
					else { continuation.resume(throwing: CocoaError(.fileWriteUnknown)) }
				}
			}
		} catch {
			failPendingSaveIfNeeded(error, fallbackOperation: operation)
			throw error
		}
	}

	@MainActor
	private func failPendingSaveIfNeeded(_ error: Error, fallbackOperation: PackagePersistenceOperation) {
		let context = stateLock.withLock { () -> SaveContext? in
			if let activeSaveContext { return activeSaveContext }
			guard requestedSaveOperation != nil else { return nil }
			requestedSaveOperation = nil
			return SaveContext(change: changeSequence, operation: fallbackOperation)
		}
		guard let context else { return }
		let failure = PackagePersistenceFailure(error: error, operation: context.operation, fileURL: fileURL)
		stateLock.withLock { activeSaveContext = nil }
		emit(.saveFailed(change: context.change, failure: failure))
	}

	@MainActor
	func revertToDisk() async throws {
		try await withCheckedThrowingContinuation { continuation in
			revert(toContentsOf: fileURL) { success in
				if success { continuation.resume() }
				else { continuation.resume(throwing: CocoaError(.fileReadUnknown)) }
			}
		}
	}

	@MainActor
	func resolveContentConflict(keepingCurrent: Bool) async throws {
		if keepingCurrent {
			try await saveNow(operation: .conflictResolution)
			try resolvePackageFileVersions(at: fileURL, keepingCurrent: true)
		} else {
			discardUnsavedChanges()
			try resolvePackageFileVersions(at: fileURL, keepingCurrent: false)
			try await revertToDisk()
		}
	}

	@MainActor
	func closeSession() async throws {
		if let explicitSaveTask { try await explicitSaveTask.value }
		if currentChange > lastPersistedChange {
			try await saveNow(operation: .close)
		}
		do {
			try await withCheckedThrowingContinuation { continuation in
				close { success in
					if success { continuation.resume() }
					else { continuation.resume(throwing: CocoaError(.fileWriteUnknown)) }
				}
			}
			NotificationCenter.default.removeObserver(
				self,
				name: UIDocument.stateChangedNotification,
				object: self
			)
		} catch {
			failPendingSaveIfNeeded(error, fallbackOperation: .close)
			throw error
		}
	}
}
#endif
