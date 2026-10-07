#if !os(watchOS)
import Foundation
import Observation

public enum PackageExternalConflictKind: Equatable, Sendable {
	case modified
	case moved
	case deleted
}

public struct PackageExternalConflict<ID: Hashable & Sendable>: Equatable, Sendable where ID: Equatable {
	public let id: ID
	public let documentName: String
	public let kind: PackageExternalConflictKind

	init(id: ID, documentName: String, kind: PackageExternalConflictKind) {
		self.id = id
		self.documentName = documentName
		self.kind = kind
	}
}

public enum PackageExternalConflictResolution: Sendable {
	case keepMyChanges
	case useExternalVersion
}

public enum PackageImportConflictResolution: Equatable, Sendable {
	case replaceExisting
	case importAsCopy
}

public enum PackageDocumentLibraryError: LocalizedError, Sendable {
	case documentNotFound(String)
	case documentNotActive(String)
	case documentReadOnly(String)

	public var errorDescription: String? {
		switch self {
		case .documentNotFound(let id): return "Document not found: \(id)"
		case .documentNotActive(let id): return "Document is not active for saving: \(id). Reopen the document and try again."
		case .documentReadOnly(let id): return "Document \(id) uses a newer readable format and is read-only in this version of the app."
		}
	}
}

public struct PackageImportConflict<ID: Hashable & Sendable>: Equatable, Sendable where ID: Equatable {
	public let id: ID
	public let existingName: String
	public let existingModifiedAt: Date
	public let incomingName: String
	public let incomingModifiedAt: Date

	init(
		id: ID,
		existingName: String,
		existingModifiedAt: Date,
		incomingName: String,
		incomingModifiedAt: Date
	) {
		self.id = id
		self.existingName = existingName
		self.existingModifiedAt = existingModifiedAt
		self.incomingName = incomingName
		self.incomingModifiedAt = incomingModifiedAt
	}
}

/// Reusable catalog + active-package lifecycle for app-controlled package documents.
///
/// Platform differences are entirely below this type: `PackageSession` uses
/// `UIDocument` where available and the tvOS presenter backend on Apple TV.
@Observable
@MainActor
public final class PackageDocumentLibrary<Document: PackageDocument> {
	typealias Snapshot = Document.Snapshot
	typealias ID = Snapshot.ID
	typealias Session = PackageSession<Document>

	public private(set) var availableDocuments: [Document]
	public private(set) var contentRevision = 0
	private(set) var externalConflicts: [ID: PackageExternalConflict<ID>] = [:]
	public private(set) var importConflict: PackageImportConflict<Document.Snapshot.ID>?
	public private(set) var catalogIssues: [PackageCatalogIssue] = []
	public private(set) var notices: [PackageDocumentNotice] = []
	public let storageKind: PackageDocumentStorageKind
	private var persistenceNoticeIDs: [ID: UUID] = [:]

	private let location: PackageStorageLocation<ID>
	private let rootDirectory: URL
	private let usesUbiquitousCatalog: Bool
	private let catalog: PackageLibraryStore<ID, Snapshot>
	private var liveDocuments: [ID: Document] = [:]
	private var sessions: [ID: Session] = [:]
	private var saveErrorHandlers: [ID: @MainActor @Sendable (Error) -> Void] = [:]
	private var persistenceStates: [ID: PackageDocumentPersistenceState] = [:]
	private var libraryMonitor: UbiquitousDirectoryMonitor?
	private var pendingImport: Snapshot?
	/// User documents disappear from discovery as soon as deletion is requested,
	/// before session close and coordinated filesystem removal finish.
	private var deletionRequestedIDs: Set<ID> = []
	private var persistedIDs: Set<ID> = []
	/// Package filenames known to exist in the resolved storage universe, including
	/// metadata-visible iCloud items whose contents cannot currently be decoded.
	private var presentPackageNames: Set<String> = []
	/// Canonical package names reserved by the most recent catalog scan. This can
	/// be broader than `presentPackageNames` when a decodable package is misnamed.
	private var catalogOccupiedPackageNames: Set<String> = []
	private var initialLoadCompleted = false
	private var initialLoadTask: Task<PackageCatalogScan<Snapshot>, Error>?
	private var refreshTask: Task<Void, Never>?
	private var activeFlushTask: Task<Void, Never>?
	private var flushAgainRequested = false
	private var pendingMetadataSnapshot: Set<URL>?
	private var catalogSnapshots: [ID: Snapshot] = [:]

	public convenience init(
		builtInDocuments: [Document] = [],
		fileManager: FileManager = .default
	) {
		self.init(builtInDocuments: builtInDocuments, fileManager: fileManager, rootDirectory: nil)
	}

	init(
		builtInDocuments: [Document] = [],
		fileManager: FileManager = .default,
		rootDirectory: URL?
	) {
		let location = Document.storageLocation(fileManager: fileManager)
		let resolution = location.resolve(rootOverride: rootDirectory)
		let resolvedRoot = resolution.directory
		let trashRoot = resolvedRoot.deletingLastPathComponent().appendingPathComponent(
			".\(resolvedRoot.lastPathComponent)-Trash",
			isDirectory: true
		)
		self.location = location
		self.rootDirectory = resolvedRoot
		self.storageKind = resolution.kind
		self.usesUbiquitousCatalog = resolution.isUbiquitous
		self.catalog = PackageLibraryStore(
			directory: resolvedRoot,
			trashDirectory: trashRoot,
			packageURL: { id in location.packageURL(for: id, root: resolvedRoot) },
			identifier: { $0.id },
			loadPackage: { url in
				let wrapper = try FileWrapper(url: url, options: .immediate)
				return try Document.snapshot(from: wrapper)
			},
			loadCatalogPackage: { url in
				try Document.catalogSnapshot(at: url)
			},
			isPackageCandidate: { url in
				url.pathExtension.caseInsensitiveCompare(location.packageExtension) == .orderedSame
			},
			issueDisplayName: { url in Document.catalogIssueDisplayName(at: url) },
			fileManager: location.fileManager
		)
		self.availableDocuments = builtInDocuments.sorted { lhs, rhs in
			lhs < rhs
		}
		for document in builtInDocuments { liveDocuments[document.id] = document }
	}

	public func load() async throws {
		if initialLoadCompleted { return }

		if usesUbiquitousCatalog {
			startLibraryMonitorIfNeeded()
			let packageURLs = await libraryMonitor?.initialPackageURLs() ?? []
			let catalog = self.catalog
			let openIDs = Set(sessions.keys).union(deletionRequestedIDs)
			let scan = await Task.detached(priority: .utility) {
				catalog.scanCatalog(packageURLs: packageURLs, excludingIDs: openIDs)
			}.value
			reconcileCatalogScan(scan, reportUnavailable: false)
			initialLoadCompleted = true
			if !scan.unavailablePackageURLs.isEmpty {
				Task { @MainActor [weak self] in
					try? await Task.sleep(nanoseconds: 1_000_000_000)
					guard let self else { return }
					await self.refreshCatalog(fromMetadata: packageURLs)
				}
			}
			return
		}

		if case .iCloudPreferred = location.policy, storageKind == .local {
			enqueueNotice(
				kind: .storageChange,
				title: "Document Storage",
				message: "iCloud storage is not currently available. This window is using local document storage and will not silently switch libraries if iCloud becomes available later."
			)
		}

		let task: Task<PackageCatalogScan<Snapshot>, Error>
		if let existing = initialLoadTask {
			task = existing
		} else {
			let catalog = self.catalog
			let openIDs = Set(sessions.keys).union(deletionRequestedIDs)
			let created = Task.detached(priority: .utility) {
				try catalog.scanCatalog(excludingIDs: openIDs)
			}
			initialLoadTask = created
			task = created
		}

		do {
			let scan = try await task.value
			if !initialLoadCompleted {
				reconcileCatalogScan(scan)
				initialLoadCompleted = true
			}
			initialLoadTask = nil
		} catch {
			initialLoadTask = nil
			throw error
		}
	}

	/// Loads a package supplied by a document picker or other external provider.
	func loadExternalSnapshot(from url: URL) async throws -> Snapshot {
		let catalog = self.catalog
		return try await Task.detached(priority: .userInitiated) {
			try catalog.loadExternalPackage(from: url)
		}.value
	}

	public func document(id: Document.Snapshot.ID) -> Document? {
		liveDocuments[id]
	}

	/// Opens a catalog document for use. Editable user documents are returned only
	/// after a live persistence session has been established.
	public func open(_ document: Document) async throws -> Document {
		let id = document.id
		let canonical = liveDocuments[id] ?? document
		guard canonical.role == .user else { return canonical }
		if sessions[id] != nil { return canonical }

		guard persistedIDs.contains(id) else {
			throw PackageDocumentLibraryError.documentNotFound(String(describing: id))
		}

		let session = makeSession(id: id, initial: canonical.snapshot)
		sessions[id] = session
		do {
			try await session.openSession(suppressingInitialLoadEvent: true)
			canonical.restore(from: session.state)
			setPersistenceState(id: id, status: .saved, currentChange: session.currentChange, persistedChange: session.currentChange)
			upsert(canonical)
			return canonical
		} catch {
			sessions[id] = nil
			throw error
		}
	}

	public func open(id: Document.Snapshot.ID) async throws -> Document? {
		if let document = document(id: id) { return try await open(document) }
		try await load()
		guard let document = document(id: id) else { return nil }
		return try await open(document)
	}

	public func open(url: URL) async throws -> Document? {
		if url.isFileURL {
			try await load()
			let incomingURL = url.standardizedFileURL
			if let existing = availableDocuments.first(where: { document in
				guard let packageURL = packageURL(for: document) else { return false }
				return packageURL.standardizedFileURL == incomingURL
			}) {
				return try await open(existing)
			}
			return try await importDocument(.success(url))
		}
		guard let id = Document.documentID(from: url) else { return nil }
		guard let document = try await open(id: id) else {
			throw PackageDocumentLibraryError.documentNotFound(String(describing: id))
		}
		return document
	}

	public func url(for document: Document) -> URL? {
		Document.url(forDocumentID: document.id)
	}

	public func createDocument() async throws -> Document {
		try await load()
		let candidate = Document.makeNewDocument()
		let requestedID = candidate.id
		let id = allocateDocumentID(preferred: requestedID)
		if id != requestedID {
			enqueueNotice(kind: .identityRepair, title: "Document Identity Repaired", message: "A generated document ID was unavailable. The new document was saved with a different ID so no existing document could be overwritten.")
		}
		let document = id == candidate.id ? candidate : Document(restoring: Document.replacingID(in: candidate.snapshot, with: id))
		return try await createPersisted(document)
	}

	public func duplicate(_ source: Document, named name: String) async throws -> Document? {
		try await load()
		guard Document.isSnapshotWritable(source.snapshot) else { throw PackageDocumentLibraryError.documentReadOnly(String(describing: source.id)) }
		let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedName.isEmpty else { return nil }
		let candidate = Document.makeDuplicate(of: source, named: trimmedName)
		let requestedID = candidate.id
		let id = allocateDocumentID(preferred: requestedID)
		if id != requestedID {
			enqueueNotice(kind: .identityRepair, title: "Document Identity Repaired", message: "The duplicate's generated document ID was unavailable. The copy was saved with a different ID so no existing document could be overwritten.")
		}
		let document = id == candidate.id ? candidate : Document(restoring: Document.replacingID(in: candidate.snapshot, with: id))

		do {
			return try await createPersisted(document)
		} catch {
			// A failed create can still leave a partial package behind. The failed
			// duplicate must never become discoverable on the next catalog scan.
			let catalog = self.catalog
			try? await Task.detached(priority: .userInitiated) {
				try catalog.moveToTrash(id: id)
			}.value
			removeFromCatalog(id: id)
			throw error
		}
	}

	public func importDocument(_ result: Result<URL, Error>) async throws -> Document? {
		try await load()
		let sourceURL = try result.get()
		try Document.validateImportURL(sourceURL)
		let loaded = try await loadExternalSnapshot(from: sourceURL)
		guard Document.isSnapshotWritable(loaded) else { throw PackageDocumentLibraryError.documentReadOnly(String(describing: loaded.id)) }
		var prepared = Document.prepareImport(loaded)
		let existingForID = liveDocuments[prepared.id]
		if !Document.isValidUserDocumentID(prepared.id) {
			prepared = Document.replacingID(in: prepared, with: allocateDocumentID())
			enqueueNotice(kind: .identityRepair, title: "Document Identity Repaired", message: "The imported document had an invalid or reserved document ID. Its data was preserved and it was imported with a new ID.")
		} else if let existingForID, existingForID.role != .user {
			prepared = Document.replacingID(in: prepared, with: allocateDocumentID())
			enqueueNotice(kind: .identityRepair, title: "Document Identity Repaired", message: "The imported document used an ID reserved by a built-in document. Its data was preserved and it was imported with a new ID.")
		}
		if let existing = liveDocuments[prepared.id], existing.role == .user {
			let incoming = Document(restoring: prepared)
			pendingImport = prepared
			importConflict = .init(
				id: prepared.id,
				existingName: existing.name,
				existingModifiedAt: existing.modifiedAt,
				incomingName: incoming.name,
				incomingModifiedAt: incoming.modifiedAt
			)
			return nil
		}
		if documentIDIsOccupied(prepared.id) {
			prepared = Document.replacingID(in: prepared, with: allocateDocumentID())
			enqueueNotice(kind: .identityRepair, title: "Document Identity Repaired", message: "The imported document's ID is already present in storage. Its data was preserved and it was imported with a new ID rather than overwriting that document.")
		}
		return try await adoptPersisted(Document.finalizedImport(prepared, asCopy: false))
	}

	public func resolveImportConflict(_ resolution: PackageImportConflictResolution) async throws -> Document? {
		guard let prepared = pendingImport else { return nil }
		pendingImport = nil
		importConflict = nil
		var finalized = Document.finalizedImport(prepared, asCopy: resolution == .importAsCopy)
		if resolution == .importAsCopy {
			finalized = Document.replacingID(in: finalized, with: allocateDocumentID(preferred: finalized.id))
		}
		return try await adoptPersisted(finalized)
	}

	public func cancelImportConflict() {
		pendingImport = nil
		importConflict = nil
	}

	public func dismissNotice(id: UUID) {
		notices.removeAll { $0.id == id }
		if let documentID = persistenceNoticeIDs.first(where: { $0.value == id })?.key {
			persistenceNoticeIDs[documentID] = nil
		}
	}

	@discardableResult
	private func enqueueNotice(kind: PackageDocumentNotice.Kind, title: String, message: String) -> UUID {
		let notice = PackageDocumentNotice(kind: kind, title: title, message: message)
		notices.append(notice)
		didChange()
		return notice.id
	}

	private func removePersistenceNotice(for id: ID) {
		guard let noticeID = persistenceNoticeIDs.removeValue(forKey: id) else { return }
		notices.removeAll { $0.id == noticeID }
	}

	public func persistenceState(for id: Document.Snapshot.ID) -> PackageDocumentPersistenceState? {
		persistenceStates[id]
	}

	/// Saves one active user document through the same coordinated persistence path
	/// used by autosave and lifecycle flushes. A clean or built-in document is a no-op.
	///
	/// The call returns only after the revision that was current when this method was
	/// entered has reached durable storage, or throws if that save attempt fails.
	public func save(
		_ document: Document,
		operation: PackagePersistenceOperation = .explicitSave
	) async throws {
		guard document.role == .user else { return }
		guard Document.isSnapshotWritable(document.snapshot) else {
			throw PackageDocumentLibraryError.documentReadOnly(String(describing: document.id))
		}
		guard let session = sessions[document.id] else {
			throw PackageDocumentLibraryError.documentNotActive(String(describing: document.id))
		}
		let targetChange = session.currentChange
		guard targetChange > session.lastPersistedChange else { return }

		do {
			try await session.saveNow(operation: operation)
			reconcilePersistenceState(id: document.id, session: session, savedAt: .now)
		} catch {
			if persistenceStates[document.id]?.status != .failed {
				recordSaveFailure(id: document.id, change: targetChange, error: error, operation: operation)
			}
			throw error
		}

		guard session.lastPersistedChange >= targetChange else {
			let error = CocoaError(.fileWriteUnknown)
			recordSaveFailure(id: document.id, change: targetChange, error: error, operation: operation)
			throw error
		}
	}

	/// A save barrier for every dirty active document. Unlike `flushAll`, failures
	/// are returned to the caller after every targeted document has been attempted.
	/// Each target is the change revision current when the barrier begins.
	public func flushAllRequiringSuccess(
		operation: PackagePersistenceOperation = .explicitSave
	) async throws {
		let targets = sessions.mapValues(\.currentChange)
		var failures: [PackagePersistenceFailure] = []

		for (id, targetChange) in targets {
			guard let session = sessions[id], targetChange > session.lastPersistedChange else { continue }
			do {
				try await session.saveNow(operation: operation)
				reconcilePersistenceState(id: id, session: session, savedAt: .now)
				if session.lastPersistedChange < targetChange {
					let error = CocoaError(.fileWriteUnknown)
					recordSaveFailure(id: id, change: targetChange, error: error, operation: operation)
					if let failure = persistenceStates[id]?.lastFailure { failures.append(failure) }
				}
			} catch {
				if persistenceStates[id]?.status != .failed {
					recordSaveFailure(id: id, change: targetChange, error: error, operation: operation)
				}
				if let failure = persistenceStates[id]?.lastFailure {
					failures.append(failure)
				} else {
					failures.append(PackagePersistenceFailure(
						error: error,
						operation: operation,
						fileURL: location.packageURL(for: id, root: rootDirectory)
					))
				}
			}
		}

		if !failures.isEmpty {
			throw PackagePersistenceBarrierError(failures: failures)
		}
	}

	/// Forces all open dirty documents through their real persistence path.
	/// Concurrent flush requests coalesce into the same in-flight operation.
	/// Failures are retained in `persistenceState` and the notice queue.
	public func flushAll(operation: PackagePersistenceOperation = .explicitSave) async {
		if let activeFlushTask {
			flushAgainRequested = true
			await activeFlushTask.value
			return
		}

		let task = Task { @MainActor [weak self] in
			guard let self else { return }
			repeat {
				self.flushAgainRequested = false
				await self.performFlushAll(operation: operation)
			} while self.flushAgainRequested && self.sessions.values.contains { $0.currentChange > $0.lastPersistedChange }
		}
		activeFlushTask = task
		defer {
			activeFlushTask = nil
			flushAgainRequested = false
		}
		await task.value
	}

	private func performFlushAll(operation: PackagePersistenceOperation) async {
		for (id, session) in sessions where session.currentChange > session.lastPersistedChange {
			do {
				try await session.saveNow(operation: operation)
				reconcilePersistenceState(id: id, session: session, savedAt: .now)
			} catch {
				// PackageSession normally emits the detailed failure itself. This fallback
				// covers failures that occur before the coordinated write begins.
				if persistenceStates[id]?.status != .failed {
					recordSaveFailure(id: id, change: session.currentChange, error: error, operation: operation)
				}
			}
		}
	}

	private func reconcilePersistenceState(id: ID, session: Session, savedAt: Date?) {
		let current = session.currentChange
		let persisted = session.lastPersistedChange
		let prior = persistenceStates[id]
		persistenceStates[id] = PackageDocumentPersistenceState(
			status: current > persisted ? .dirty : .saved,
			currentChange: current,
			persistedChange: persisted,
			lastSuccessfulSaveAt: savedAt ?? prior?.lastSuccessfulSaveAt,
			lastFailure: current > persisted ? prior?.lastFailure : nil
		)
		if current <= persisted { removePersistenceNotice(for: id) }
		didChange()
	}

	func createPersisted(_ document: Document) async throws -> Document {
		try prepareRootDirectory()
		let id = document.id
		deletionRequestedIDs.remove(id)
		let session = makeSession(id: id, initial: document.snapshot)
		liveDocuments[id] = document
		sessions[id] = session
		do {
			try await session.createSession()
			persistedIDs.insert(id)
			presentPackageNames.insert(location.packageName(for: id))
			catalogOccupiedPackageNames.insert(location.packageName(for: id))
			setPersistenceState(id: id, status: .saved, currentChange: session.currentChange, persistedChange: session.currentChange, savedAt: .now)
			upsert(document)
			return document
		} catch {
			sessions[id] = nil
			liveDocuments[id] = nil
			throw error
		}
	}

	public func delete(_ document: Document) async throws {
		guard document.role == .user else { return }
		let id = document.id

		// Deletion is user intent. Hide the document immediately, then close any
		// live session and atomically move the intact package out of the discovery
		// root. Physical removal from trash is asynchronous housekeeping.
		deletionRequestedIDs.insert(id)
		rebuildAvailableDocuments()

		do {
			if let session = sessions[id] {
				session.discardUnsavedChanges()
				try await session.closeSession()
			}
			let catalog = self.catalog
			try await Task.detached(priority: .userInitiated) { try catalog.moveToTrash(id: id) }.value
			removeFromCatalog(id: id)

			// Deletion is complete from the application's point of view once the
			// move succeeds. Cleanup failure is nonfatal and retried at next launch.
			Task.detached(priority: .utility) { try? catalog.emptyTrash() }
		} catch {
			// A failed move means the package is still live. Restore discovery and
			// preserve the original error for the caller.
			deletionRequestedIDs.remove(id)
			rebuildAvailableDocuments()
			throw error
		}
	}


	/// Deletes a package that is present in the catalog but could not be decoded.
	/// The URL comes from the catalog scan itself; `PackageLibraryStore` revalidates
	/// that it belongs to this library before moving it to private trash.
	public func deleteCatalogIssue(_ issue: PackageCatalogIssue) async throws {
		let catalog = self.catalog
		let url = issue.packageURL
		catalogIssues.removeAll { $0.id == issue.id }
		do {
			try await Task.detached(priority: .userInitiated) {
				try catalog.moveToTrash(packageURL: url)
			}.value
			presentPackageNames.remove(url.lastPathComponent)
			catalogOccupiedPackageNames.remove(url.lastPathComponent)
			didChange()
			Task.detached(priority: .utility) { try? catalog.emptyTrash() }
		} catch {
			try? await refreshCatalog()
			throw error
		}
	}

	/// Removes any packages or rogue files left in the private trash directory.
	/// Intended for nonblocking housekeeping such as app launch.
	public func emptyTrash() async {
		let catalog = self.catalog
		await Task.detached(priority: .utility) { try? catalog.emptyTrash() }.value
	}

	public func documentDidChange(
		_ document: Document,
		onSaveError: (@MainActor @Sendable (Error) -> Void)? = nil
	) {
		guard document.role == .user else { return }
		guard Document.isSnapshotWritable(document.snapshot) else {
			let error = PackageDocumentLibraryError.documentReadOnly(String(describing: document.id))
			onSaveError?(error)
			return
		}
		guard let session = sessions[document.id] else {
			let error = PackageDocumentLibraryError.documentNotActive(String(describing: document.id))
			onSaveError?(error)
			return
		}
		document.markModified()
		let id = document.id
		if let onSaveError { saveErrorHandlers[id] = onSaveError }
		let change = session.replaceState(document.snapshot)
		let prior = persistenceStates[id]
		persistenceStates[id] = PackageDocumentPersistenceState(
			status: .dirty,
			currentChange: change,
			persistedChange: prior?.persistedChange ?? max(0, change - 1),
			lastSuccessfulSaveAt: prior?.lastSuccessfulSaveAt,
			lastFailure: prior?.lastFailure
		)
		upsert(document)
	}

	/// Installs an already-prepared persisted snapshot. If the stable ID is open,
	/// the existing canonical live object is retained and restored in place.
	@discardableResult
	func adoptPersisted(_ snapshot: Snapshot) async throws -> Document {
		let id = snapshot.id
		if let existing = liveDocuments[id], existing.role == .user {
			let canonical = try await open(existing)
			if let session = sessions[id] {
				let change = session.replaceState(snapshot)
				try await session.saveNow(operation: .explicitSave)
				setPersistenceState(id: id, status: .saved, currentChange: change, persistedChange: change, savedAt: .now)
				canonical.restore(from: snapshot)
				upsert(canonical)
				return canonical
			}
		}
		return try await createPersisted(Document(restoring: snapshot))
	}

	public func packageURL(for document: Document) -> URL? {
		guard document.role == .user else { return nil }
		return location.packageURL(for: document.id, root: rootDirectory)
	}

	public func exportPackage(_ document: Document) async throws -> URL {
		guard Document.isSnapshotWritable(document.snapshot) else { throw PackageDocumentLibraryError.documentReadOnly(String(describing: document.id)) }
		let snapshot = Document.snapshotForExport(document.snapshot)
		let writer = ExportArtifactWriter(directoryName: "DocumentExports", fileManager: location.fileManager)
		let packageExtension = location.packageExtension
		let preferredName = document.name.sanitizedFilename(removeSpaces: false)
		let name = preferredName.hasContent ? preferredName : "Document"
		return try await Task.detached(priority: .userInitiated) {
			let wrapper = try Document.fileWrapper(for: snapshot)
			return try writer.write(wrapper, named: name, extension: packageExtension)
		}.value
	}

	public func externalConflict(for id: Document.Snapshot.ID) -> PackageExternalConflict<Document.Snapshot.ID>? {
		externalConflicts[id]
	}

	@discardableResult
	public func resolveExternalConflict(
		id: Document.Snapshot.ID,
		resolution: PackageExternalConflictResolution
	) async throws -> Bool {
		guard let conflict = externalConflicts[id],
			let document = liveDocuments[id],
			let session = sessions[id]
		else { return liveDocuments[id] != nil }

		switch (conflict.kind, resolution) {
		case (.modified, .keepMyChanges):
			session.replaceState(document.snapshot)
			try await session.resolveContentConflict(keepingCurrent: true)
		case (.modified, .useExternalVersion):
			try await session.resolveContentConflict(keepingCurrent: false)
		case (.moved, .keepMyChanges), (.deleted, .keepMyChanges):
			session.discardUnsavedChanges()
			try await session.closeSession()
			sessions[id] = nil
			try await recreateCanonicalPackage(for: document)
		case (.moved, .useExternalVersion), (.deleted, .useExternalVersion):
			session.discardUnsavedChanges()
			try await session.closeSession()
			removeFromCatalog(id: id)
			return false
		}
		externalConflicts[id] = nil
		didChange()
		return true
	}

	private func reconcileCatalogScan(
		_ scan: PackageCatalogScan<Snapshot>,
		reportUnavailable: Bool = true
	) {
		let deletionPackageNames = Set(deletionRequestedIDs.map { location.packageName(for: $0) })
		catalogIssues = scan.issues.filter { !deletionPackageNames.contains($0.packageName) }
		presentPackageNames = scan.presentPackageNames
		catalogOccupiedPackageNames = scan.occupiedPackageNames
		// A metadata-visible iCloud package can be temporarily unreadable for reasons
		// that are not actionable by the user (download/materialization/coordination
		// races). Keep those packages present so they cannot be mistaken for deleted,
		// but do not interrupt app launch with a modal alert. Real open/save failures
		// are reported through their own user-facing persistence paths.
		if reportUnavailable {
			for url in scan.unavailablePackageURLs.sorted(by: { $0.path < $1.path }) {
				#if DEBUG
				print("[DocumentStorage] iCloud catalog package is currently unreadable; preserving catalog presence and retrying: \(url.lastPathComponent)")
				#endif
			}
		}
		let activeIDs = Set(sessions.keys)
		let staleIDs = persistedIDs.subtracting(activeIDs).filter { id in
			!scan.presentPackageNames.contains(location.packageURL(for: id, root: rootDirectory).lastPathComponent)
		}
		var changed = false

		for id in staleIDs {
			changed = removeCatalogState(id: id) || changed
		}

		for snapshot in scan.states {
			let id = snapshot.id
			persistedIDs.insert(id)
			guard catalogSnapshots[id] != snapshot else { continue }
			catalogSnapshots[id] = snapshot
			if let existing = liveDocuments[id], sessions[id] == nil {
				existing.restoreCatalog(from: snapshot)
			} else if liveDocuments[id] == nil {
				liveDocuments[id] = Document(restoring: snapshot)
			}
			changed = true
		}

		if changed { rebuildAvailableDocuments() }
	}

	private func refreshCatalog() async throws {
		let catalog = self.catalog
		let openIDs = Set(sessions.keys).union(deletionRequestedIDs)
		if usesUbiquitousCatalog {
			let packageURLs = libraryMonitor?.currentPackageURLs() ?? []
			let scan = await Task.detached(priority: .utility) {
				catalog.scanCatalog(packageURLs: packageURLs, excludingIDs: openIDs)
			}.value
			reconcileCatalogScan(scan)
		} else {
			let scan = try await Task.detached(priority: .utility) {
				try catalog.scanCatalog(excludingIDs: openIDs)
			}.value
			reconcileCatalogScan(scan)
		}
	}

	private func refreshCatalog(fromMetadata packageURLs: Set<URL>) async {
		let catalog = self.catalog
		let openIDs = Set(sessions.keys).union(deletionRequestedIDs)
		let scan = await Task.detached(priority: .utility) {
			catalog.scanCatalog(packageURLs: packageURLs, excludingIDs: openIDs)
		}.value
		reconcileCatalogScan(scan)
	}

	private func refreshCatalog(at packageURLs: Set<URL>) async throws {
		guard !packageURLs.isEmpty else { return }
		let catalog = self.catalog
		let excludedIDs = Set(sessions.keys).union(deletionRequestedIDs)
		let openPackageNames = Set(excludedIDs.map { location.packageURL(for: $0, root: rootDirectory).lastPathComponent })
		let urls = packageURLs.filter { !openPackageNames.contains($0.lastPathComponent) }
		guard !urls.isEmpty else { return }

		let loaded = await Task.detached(priority: .utility) {
			urls.map { url -> (URL, Snapshot?, Bool) in
				do { return (url, try catalog.loadCatalogPackage(at: url), true) }
				catch { return (url, nil, false) }
			}
		}.value

		var changed = false
		for (url, snapshot, readSucceeded) in loaded {
			guard readSucceeded else { continue }
			let priorID = persistedIDs.first {
				location.packageURL(for: $0, root: rootDirectory).lastPathComponent == url.lastPathComponent
			}

			guard let snapshot else {
				if let priorID { changed = removeCatalogState(id: priorID) || changed }
				continue
			}

			let id = snapshot.id
			if let priorID, priorID != id {
				changed = removeCatalogState(id: priorID) || changed
			}
			persistedIDs.insert(id)
			guard catalogSnapshots[id] != snapshot else { continue }
			catalogSnapshots[id] = snapshot
			if let existing = liveDocuments[id], sessions[id] == nil {
				existing.restoreCatalog(from: snapshot)
			} else if liveDocuments[id] == nil {
				liveDocuments[id] = Document(restoring: snapshot)
			}
			changed = true
		}

		if changed { rebuildAvailableDocuments() }
	}

	private func requestCatalogRefresh(_ change: UbiquitousDirectoryMonitor.Change) {
		switch change {
		case .snapshot(let urls):
			pendingMetadataSnapshot = urls
		}
		guard refreshTask == nil else { return }

		refreshTask = Task { @MainActor [weak self] in
			guard let self else { return }
			while let urls = self.pendingMetadataSnapshot {
				self.pendingMetadataSnapshot = nil
				await self.refreshCatalog(fromMetadata: urls)
			}
			self.refreshTask = nil
		}
	}


	private func makeSession(id: ID, initial: Snapshot) -> Session {
		Session(
			fileURL: location.packageURL(for: id, root: rootDirectory),
			state: initial
		) { [weak self] event in
			await self?.handleSessionEvent(id: id, event: event)
		}
	}

	private func handleSessionEvent(id: ID, event: PackageSessionEvent<Snapshot>) async {
		switch event {
		case .loaded(let snapshot):
			guard snapshot.id == id, let document = liveDocuments[id] else { return }
			document.restore(from: snapshot)
			if let session = sessions[id] {
				let prior = persistenceStates[id]
				persistenceStates[id] = PackageDocumentPersistenceState(
					status: .saved,
					currentChange: session.currentChange,
					persistedChange: session.currentChange,
					lastSuccessfulSaveAt: prior?.lastSuccessfulSaveAt,
					lastFailure: nil
				)
			}
			removePersistenceNotice(for: id)
			upsert(document)
		case .conflict:
			guard let document = liveDocuments[id] else { return }
			externalConflicts[id] = .init(
				id: id,
				documentName: document.name,
				kind: .modified
			)
			didChange()
		case .moved:
			await handleExternalRemoval(id: id, kind: .moved)
		case .deleted:
			await handleExternalRemoval(id: id, kind: .deleted)
		case .saveStarted(let change, let operation):
			let prior = persistenceStates[id]
			guard change > (prior?.persistedChange ?? -1) else {
				logPersistence(id: id, "ignored stale save start: \(operation.rawValue), change \(change)")
				return
			}
			persistenceStates[id] = PackageDocumentPersistenceState(
				status: .saving,
				currentChange: max(prior?.currentChange ?? change, change),
				persistedChange: prior?.persistedChange ?? 0,
				lastSuccessfulSaveAt: prior?.lastSuccessfulSaveAt,
				lastFailure: prior?.lastFailure
			)
			logPersistence(id: id, "save started: \(operation.rawValue), change \(change)")
			didChange()
		case .saveSucceeded(let change, let operation, let date):
			let prior = persistenceStates[id]
			if change < (prior?.persistedChange ?? 0) {
				logPersistence(id: id, "ignored stale save success: \(operation.rawValue), change \(change)")
				return
			}
			let current = max(prior?.currentChange ?? change, change)
			let persisted = max(prior?.persistedChange ?? 0, change)
			persistenceStates[id] = PackageDocumentPersistenceState(
				status: current > persisted ? .dirty : .saved,
				currentChange: current,
				persistedChange: persisted,
				lastSuccessfulSaveAt: date,
				lastFailure: current > persisted ? prior?.lastFailure : nil
			)
			if current <= persisted { removePersistenceNotice(for: id) }
			logPersistence(id: id, "save succeeded: \(operation.rawValue), change \(change)")
			didChange()
		case .saveFailed(let change, let failure):
			recordSaveFailure(id: id, change: change, failure: failure)
		case .error(let error):
			saveErrorHandlers[id]?(error)
		case .warning(let warning):
			enqueueNotice(kind: .resourceWarning, title: "Document Resource Warning", message: warning.localizedDescription)
		}
	}

	private func handleExternalRemoval(id: ID, kind: PackageExternalConflictKind) async {
		guard let session = sessions[id], let document = liveDocuments[id] else { return }
		if session.currentChange > session.lastPersistedChange {
			externalConflicts[id] = .init(
				id: id,
				documentName: document.name,
				kind: kind
			)
			didChange()
			return
		}

		do {
			try await session.closeSession()
		} catch {
			recordSaveFailure(id: id, change: session.currentChange, error: error, operation: .close)
			return
		}
		removeFromCatalog(id: id)
	}

	private func recreateCanonicalPackage(for document: Document) async throws {
		try prepareRootDirectory()
		let id = document.id
		let session = makeSession(id: id, initial: document.snapshot)
		sessions[id] = session
		do {
			try await session.createSession()
			persistedIDs.insert(id)
			presentPackageNames.insert(location.packageName(for: id))
			catalogOccupiedPackageNames.insert(location.packageName(for: id))
			setPersistenceState(id: id, status: .saved, currentChange: session.currentChange, persistedChange: session.currentChange, savedAt: .now)
			upsert(document)
		} catch {
			if persistenceStates[id]?.status != .failed {
				recordSaveFailure(id: id, change: session.currentChange, error: error, operation: .recreate)
			}
			throw error
		}
	}

	private func documentIDIsOccupied(_ id: ID) -> Bool {
		if liveDocuments[id] != nil || persistedIDs.contains(id) || catalogSnapshots[id] != nil { return true }
		let packageName = location.packageName(for: id)
		if presentPackageNames.contains(packageName) || catalogOccupiedPackageNames.contains(packageName) { return true }
		let url = location.packageURL(for: id, root: rootDirectory)
		return location.fileManager.fileExists(atPath: url.path)
	}

	private func allocateDocumentID(preferred: ID? = nil) -> ID {
		if let preferred, Document.isValidUserDocumentID(preferred), !documentIDIsOccupied(preferred) {
			return preferred
		}
		while true {
			let candidate = Document.makeDocumentID()
			if Document.isValidUserDocumentID(candidate), !documentIDIsOccupied(candidate) { return candidate }
		}
	}

	private func setPersistenceState(
		id: ID,
		status: PackageDocumentPersistenceStatus,
		currentChange: Int,
		persistedChange: Int,
		savedAt: Date? = nil
	) {
		let prior = persistenceStates[id]
		persistenceStates[id] = PackageDocumentPersistenceState(
			status: status,
			currentChange: currentChange,
			persistedChange: persistedChange,
			lastSuccessfulSaveAt: savedAt ?? prior?.lastSuccessfulSaveAt,
			lastFailure: status == .failed ? prior?.lastFailure : nil
		)
	}

	private func recordSaveFailure(
		id: ID,
		change: Int,
		error: Error,
		operation: PackagePersistenceOperation
	) {
		recordSaveFailure(
			id: id,
			change: change,
			failure: PackagePersistenceFailure(
				error: error,
				operation: operation,
				fileURL: location.packageURL(for: id, root: rootDirectory)
			)
		)
	}

	private func recordSaveFailure(id: ID, change: Int, failure: PackagePersistenceFailure) {
		let prior = persistenceStates[id]
		guard change > (prior?.persistedChange ?? -1) else {
			logPersistence(id: id, "ignored stale save failure: \(failure.diagnosticDescription)")
			return
		}
		persistenceStates[id] = PackageDocumentPersistenceState(
			status: .failed,
			currentChange: max(prior?.currentChange ?? change, change),
			persistedChange: prior?.persistedChange ?? 0,
			lastSuccessfulSaveAt: prior?.lastSuccessfulSaveAt,
			lastFailure: failure
		)
		removePersistenceNotice(for: id)
		persistenceNoticeIDs[id] = enqueueNotice(
			kind: .persistenceFailure,
			title: "Document Not Saved",
			message: failure.localizedDescription
		)
		logPersistence(id: id, failure.diagnosticDescription)
		didChange()
	}

	private func logPersistence(id: ID, _ message: String) {
		NSLog("[PackageDocumentLibrary] document=%@ %@", String(describing: id), message)
	}

	private func prepareRootDirectory() throws {
		try location.fileManager.createDirectory(
			at: rootDirectory,
			withIntermediateDirectories: true
		)
	}

	private func startLibraryMonitorIfNeeded() {
		guard usesUbiquitousCatalog, libraryMonitor == nil else { return }
		libraryMonitor = UbiquitousDirectoryMonitor(
			directoryURL: { [rootDirectory] in rootDirectory },
			packageExtension: location.packageExtension,
			onIdentityChange: { [weak self] in
				guard let self else { return }
				self.enqueueNotice(
					kind: .storageChange,
					title: "Document Storage Changed",
					message: "The iCloud account or iCloud Drive availability changed. This window will keep using the document library it opened with rather than silently switching storage. Close and reopen the window to use the newly available storage."
				)
			},
			onChange: { [weak self] change in
				guard let self else { return }
				Task { @MainActor in self.requestCatalogRefresh(change) }
			}
		)
	}

	private func rebuildAvailableDocuments() {
		availableDocuments = liveDocuments.values
			.filter { !deletionRequestedIDs.contains($0.id) }
			.sorted { lhs, rhs in lhs < rhs }
		didChange()
	}

	private func upsert(_ document: Document) {
		let id = document.id
		liveDocuments[id] = document
		availableDocuments.removeAll { $0.id == id }
		guard !deletionRequestedIDs.contains(id) else {
			didChange()
			return
		}
		availableDocuments.append(document)
		availableDocuments.sort { lhs, rhs in
			lhs < rhs
		}
		didChange()
	}

	@discardableResult
	private func removeCatalogState(id: ID) -> Bool {
		let packageName = location.packageName(for: id)
		let existed = persistedIDs.contains(id) || liveDocuments[id] != nil || catalogSnapshots[id] != nil || presentPackageNames.contains(packageName)
		persistedIDs.remove(id)
		presentPackageNames.remove(packageName)
		catalogSnapshots[id] = nil
		sessions[id] = nil
		liveDocuments[id] = nil
		saveErrorHandlers[id] = nil
		persistenceStates[id] = nil
		externalConflicts[id] = nil
		return existed
	}

	private func removeFromCatalog(id: ID) {
		guard removeCatalogState(id: id) else { return }
		availableDocuments.removeAll { $0.id == id }
		didChange()
	}

	private func didChange() {
		contentRevision &+= 1
	}
}

#endif
