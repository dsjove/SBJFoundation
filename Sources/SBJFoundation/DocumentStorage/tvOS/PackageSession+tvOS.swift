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
	private var currentURL: URL
	private var presenterRegistered = false
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
		Task { @MainActor [onEvent] in await onEvent(event) }
	}

	@MainActor
	func replaceState(_ state: Snapshot) {
		stateLock.withLock {
			storedState = state
			dirty = true
		}
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
		do {
			try writeState()
			stateLock.withLock { dirty = false }
			registerPresenterIfNeeded()
		} catch {
			emit(.error(error))
			throw error
		}
	}

	@MainActor
	func saveNow() async throws {
		guard hasUnsavedChanges else { return }
		do {
			let wasRegistered = removePresenterIfRegistered()
			defer { if wasRegistered { registerPresenterIfNeeded() } }
			try writeState()
			stateLock.withLock { dirty = false }
		} catch {
			emit(.error(error))
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
			try await saveNow()
			try resolvePackageFileVersions(at: fileURL, keepingCurrent: true)
		} else {
			discardUnsavedChanges()
			try resolvePackageFileVersions(at: fileURL, keepingCurrent: false)
			try await revertToDisk()
		}
	}

	@MainActor
	func closeSession() async {
		try? await saveNow()
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
		let wrapper = try Document.fileWrapper(for: state)
		let url = fileURL
		try FileManager.default.createDirectory(
			at: url.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		var coordinationError: NSError?
		var operationError: Error?
		NSFileCoordinator(filePresenter: nil).coordinate(
			writingItemAt: url,
			options: .forReplacing,
			error: &coordinationError
		) { coordinatedURL in
			do {
				try wrapper.write(
					to: coordinatedURL,
					options: .atomic,
					originalContentsURL: FileManager.default.fileExists(atPath: coordinatedURL.path)
						? coordinatedURL
						: nil
				)
			} catch {
				operationError = error
			}
		}
		if let coordinationError { throw coordinationError }
		if let operationError { throw operationError }
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
