#if os(tvOS)
import Foundation

/// Active lifecycle for one package-backed file on tvOS.
///
/// tvOS has no `UIDocument`, so this backend uses `NSFilePresenter` and
/// `NSFileCoordinator`. The public API intentionally matches the UIKit-backed
/// `PackageSession`; clients never branch on platform.
final class PackageSession<Document: PackageDocument>: NSObject, NSFilePresenter, @unchecked Sendable {
	typealias Snapshot = Document.Snapshot
	private let stateLock = NSLock()
	private var storedState: Snapshot
	private var dirty = false
	private var changeSequence = 0
	private var persistedChangeSequence = 0
	private var currentURL: URL
	private var presenterRegistered = false
	private let eventLock = NSLock()
	private var eventDeliveryTask: Task<Void, Never>?
	@MainActor private var explicitSaveTask: Task<Void, Error>?
	@MainActor private var explicitSaveRequestedAgain = false
	private let onEvent: @MainActor @Sendable (PackageSessionEvent<Snapshot>) async -> Void
	private let presenterQueue: OperationQueue = {
		let queue = OperationQueue()
		queue.name = "SBJFoundation.PackageSession.NSFilePresenter"
		queue.maxConcurrentOperationCount = 1
		return queue
	}()

	var state: Snapshot {
		stateLock.withLock { storedState }
	}

	var fileURL: URL {
		stateLock.withLock { currentURL }
	}

	var hasUnsavedChanges: Bool {
		stateLock.withLock { dirty }
	}

	var currentChange: Int {
		stateLock.withLock { changeSequence }
	}

	var lastPersistedChange: Int {
		stateLock.withLock { persistedChangeSequence }
	}

	var presentedItemURL: URL? { fileURL }
	var presentedItemOperationQueue: OperationQueue { presenterQueue }

	init(
		fileURL: URL,
		state: Snapshot,
		onEvent: @escaping @MainActor @Sendable (PackageSessionEvent<Snapshot>) async -> Void
	) {
		self.currentURL = fileURL
		self.storedState = state
		self.onEvent = onEvent
		super.init()
	}

	deinit {
		removePresenterIfRegistered()
	}

	func presentedItemDidChange() {
		if hasUnsavedChanges {
			emit(.conflict)
			return
		}
		do {
			let loaded = try readState(filePresenter: self)
			stateLock.withLock {
				storedState = loaded
				dirty = false
			}
			emit(.loaded(loaded))
		} catch {
			emit(.error(error))
		}
	}

	func presentedItemDidMove(to newURL: URL) {
		stateLock.withLock { currentURL = newURL }
		emit(.moved(newURL))
	}

	func accommodatePresentedItemDeletion(
		completionHandler: @escaping @Sendable (Error?) -> Void
	) {
		emit(.deleted)
		completionHandler(nil)
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
			dirty = true
			changeSequence &+= 1
			return changeSequence
		}
		return change
	}

	@MainActor
	func discardUnsavedChanges() {
		stateLock.withLock { dirty = false }
	}

	@MainActor
	func openSession(suppressingInitialLoadEvent: Bool = false) async throws {
		do {
			let loaded = try readStateAndRegisterPresenter()
			stateLock.withLock {
				storedState = loaded
				dirty = false
			}
			if !suppressingInitialLoadEvent { emit(.loaded(loaded)) }
		} catch {
			emit(.error(error))
			throw error
		}
	}

	@MainActor
	func createSession() async throws {
		let change = currentChange
		emit(.saveStarted(change: change, operation: .create))
		do {
			try writeState()
			stateLock.withLock {
				dirty = false
				persistedChangeSequence = max(persistedChangeSequence, change)
			}
			registerPresenterIfNeeded()
			emit(.saveSucceeded(change: change, operation: .create, at: .now))
		} catch {
			emit(.saveFailed(change: change, failure: .init(error: error, operation: .create, fileURL: fileURL)))
			throw error
		}
	}

	@MainActor
	func saveNow(operation: PackagePersistenceOperation = .explicitSave) async throws {
		if let explicitSaveTask {
			explicitSaveRequestedAgain = true
			try await explicitSaveTask.value
			return
		}
		guard hasUnsavedChanges else { return }

		let task = Task { @MainActor [weak self] in
			guard let self else { return }
			repeat {
				self.explicitSaveRequestedAgain = false
				try await self.performSaveNow(operation: operation)
			} while self.explicitSaveRequestedAgain && self.hasUnsavedChanges
		}
		explicitSaveTask = task
		defer {
			explicitSaveTask = nil
			explicitSaveRequestedAgain = false
		}
		try await task.value
	}

	@MainActor
	private func performSaveNow(operation: PackagePersistenceOperation) async throws {
		guard hasUnsavedChanges else { return }
		let change = currentChange
		emit(.saveStarted(change: change, operation: operation))
		do {
			let wasRegistered = removePresenterIfRegistered()
			defer { if wasRegistered { registerPresenterIfNeeded() } }
			try writeState()
			stateLock.withLock {
				dirty = false
				persistedChangeSequence = max(persistedChangeSequence, change)
			}
			emit(.saveSucceeded(change: change, operation: operation, at: .now))
		} catch {
			emit(.saveFailed(change: change, failure: .init(error: error, operation: operation, fileURL: fileURL)))
			throw error
		}
	}

	@MainActor
	func revertToDisk() async throws {
		do {
			removePresenterIfRegistered()
			let loaded = try readStateAndRegisterPresenter()
			stateLock.withLock {
				storedState = loaded
				dirty = false
			}
			emit(.loaded(loaded))
		} catch {
			emit(.error(error))
			throw error
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
		try await saveNow(operation: .close)
		removePresenterIfRegistered()
	}

	private func readStateAndRegisterPresenter() throws -> Snapshot {
		let url = fileURL
		var coordinationError: NSError?
		var result: Result<Snapshot, Error>?
		NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
			result = Result {
				let wrapper = try FileWrapper(url: coordinatedURL, options: [])
				let loaded = try Document.snapshot(from: wrapper, at: coordinatedURL)
				stateLock.withLock { currentURL = coordinatedURL }
				registerPresenterIfNeeded()
				return loaded
			}
		}
		if let coordinationError { throw coordinationError }
		guard let result else { throw CocoaError(.fileReadUnknown) }
		return try result.get()
	}

	private func readState(filePresenter: (any NSFilePresenter)?) throws -> Snapshot {
		let url = fileURL
		var coordinationError: NSError?
		var result: Result<Snapshot, Error>?
		NSFileCoordinator(filePresenter: filePresenter).coordinate(
			readingItemAt: url,
			options: [],
			error: &coordinationError
		) { coordinatedURL in
			result = Result {
				let wrapper = try FileWrapper(url: coordinatedURL, options: [])
				return try Document.snapshot(from: wrapper, at: coordinatedURL)
			}
		}
		if let coordinationError { throw coordinationError }
		guard let result else { throw CocoaError(.fileReadUnknown) }
		return try result.get()
	}

	private func writeState() throws {
		let snapshot = state
		let url = fileURL
		try FileManager.default.createDirectory(
			at: url.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		var coordinationError: NSError?
		var operationResult: Result<[PackageDocumentWriteWarning], Error>?
		NSFileCoordinator(filePresenter: nil).coordinate(
			writingItemAt: url,
			options: .forReplacing,
			error: &coordinationError
		) { coordinatedURL in
			operationResult = Result { try Document.persist(snapshot, to: coordinatedURL) }
		}
		if let coordinationError { throw coordinationError }
		guard let operationResult else { throw CocoaError(.fileWriteUnknown) }
		for warning in try operationResult.get() { emit(.warning(warning)) }
	}

	@discardableResult
	private func registerPresenterIfNeeded() -> Bool {
		let shouldRegister = stateLock.withLock {
			guard !presenterRegistered else { return false }
			presenterRegistered = true
			return true
		}
		if shouldRegister { NSFileCoordinator.addFilePresenter(self) }
		return shouldRegister
	}

	@discardableResult
	private func removePresenterIfRegistered() -> Bool {
		let shouldRemove = stateLock.withLock {
			guard presenterRegistered else { return false }
			presenterRegistered = false
			return true
		}
		if shouldRemove { NSFileCoordinator.removeFilePresenter(self) }
		return shouldRemove
	}
}
#endif
