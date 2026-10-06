#if !os(watchOS)
import Foundation
import Testing
@testable import SBJFoundation

@Suite("Package document library")
struct PackageDocumentLibraryTests {
	private final class PersistProbe: @unchecked Sendable {
		private let lock = NSLock()
		private var _count = 0

		var count: Int { lock.withLock { _count } }

		func reset() { lock.withLock { _count = 0 } }
		func record() { lock.withLock { _count += 1 } }
	}

	private struct Snapshot: PackageDocumentSnapshot, Codable, Equatable, Sendable {
		let id: String
		var name: String
		var role: DocumentRole
		var modifiedAt: Date
		var value: String
	}

	private final class TestDocument: PackageDocument, @unchecked Sendable {
		static let persistProbe = PersistProbe()
		var snapshot: Snapshot

		var id: String { snapshot.id }
		var name: String { snapshot.name }
		var role: DocumentRole { snapshot.role }
		var modifiedAt: Date { snapshot.modifiedAt }

		init(restoring snapshot: Snapshot) {
			self.snapshot = snapshot
		}

		func restore(from snapshot: Snapshot) {
			self.snapshot = snapshot
		}

		func markModified(at date: Date) {
			snapshot.modifiedAt = date
		}

		static func < (lhs: TestDocument, rhs: TestDocument) -> Bool {
			(lhs.role, lhs.name, lhs.id) < (rhs.role, rhs.name, rhs.id)
		}

		static func == (lhs: TestDocument, rhs: TestDocument) -> Bool {
			lhs === rhs
		}

		static func makeDocumentID() -> String { UUID().uuidString }

		static func isValidUserDocumentID(_ id: String) -> Bool { !id.isEmpty && id != "built-in" }

		static func replacingID(in snapshot: Snapshot, with id: String) -> Snapshot {
			.init(id: id, name: snapshot.name, role: snapshot.role, modifiedAt: snapshot.modifiedAt, value: snapshot.value)
		}

		static func makeNewDocument() -> TestDocument {
			TestDocument(restoring: .init(
				id: UUID().uuidString,
				name: "New Document",
				role: .user,
				modifiedAt: .now,
				value: "new"
			))
		}

		static func makeDuplicate(of source: TestDocument, named name: String) -> TestDocument {
			var copy = source.snapshot
			copy = .init(
				id: UUID().uuidString,
				name: name,
				role: .user,
				modifiedAt: .now,
				value: copy.value
			)
			return TestDocument(restoring: copy)
		}

		static func storageLocation(fileManager: FileManager) -> PackageStorageLocation<String> {
			PackageStorageLocation(
				directoryName: "PackageDocumentLibraryTests",
				packageExtension: "testpkg",
				fileManager: fileManager
			)
		}

		static func validateImportURL(_ url: URL) throws {
			guard url.pathExtension == "testpkg" else { throw CocoaError(.fileReadUnsupportedScheme) }
		}

		static func prepareImport(_ snapshot: Snapshot) -> Snapshot { snapshot }

		static func finalizedImport(_ snapshot: Snapshot, asCopy: Bool) -> Snapshot {
			guard asCopy else { return snapshot }
			return .init(
				id: UUID().uuidString,
				name: snapshot.name,
				role: .user,
				modifiedAt: .now,
				value: snapshot.value
			)
		}

		static func snapshotForExport(_ snapshot: Snapshot) -> Snapshot {
			var exported = snapshot
			exported.role = .user
			return exported
		}

		static func fileWrapper(for snapshot: Snapshot) throws -> FileWrapper {
			let data = try JSONEncoder().encode(snapshot)
			return FileWrapper(directoryWithFileWrappers: [
				"state.json": FileWrapper(regularFileWithContents: data),
			])
		}

		static func persist(_ snapshot: Snapshot, to url: URL) throws -> [PackageDocumentWriteWarning] {
			persistProbe.record()
			let wrapper = try fileWrapper(for: snapshot)
			try FileManager.default.createDirectory(
				at: url.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			try wrapper.write(
				to: url,
				options: .atomic,
				originalContentsURL: FileManager.default.fileExists(atPath: url.path) ? url : nil
			)
			return []
		}

		static func snapshot(from wrapper: FileWrapper) throws -> Snapshot {
			guard let data = wrapper.fileWrappers?["state.json"]?.regularFileContents else {
				throw CocoaError(.fileReadCorruptFile)
			}
			return try JSONDecoder().decode(Snapshot.self, from: data)
		}

		static func documentID(from url: URL) -> String? {
			guard url.scheme == "test-doc", url.host == "document" else { return nil }
			let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
			return id.isEmpty ? nil : id.removingPercentEncoding
		}

		static func url(forDocumentID id: String) -> URL? {
			var components = URLComponents()
			components.scheme = "test-doc"
			components.host = "document"
			components.path = "/\(id)"
			return components.url
		}
	}

	@MainActor @Test("Creates and deletes a persisted document in the supplied root")
	func createAndDelete() async throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let library = PackageDocumentLibrary<TestDocument>(rootDirectory: root)

		let document = try await library.createDocument()
		let url = try #require(library.packageURL(for: document))
		#expect(url.deletingLastPathComponent() == root)
		#expect(FileManager.default.fileExists(atPath: url.path))
		#expect(library.document(id: document.id) === document)

		try await library.delete(document)
		#expect(library.document(id: document.id) == nil)
		#expect(!FileManager.default.fileExists(atPath: url.path))
	}

	@MainActor @Test("Duplication creates a new persisted user identity")
	func duplicateCreatesNewIdentity() async throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let library = PackageDocumentLibrary<TestDocument>(rootDirectory: root)
		let source = try await library.createPersisted(TestDocument(restoring: .init(
			id: "source-id",
			name: "Source",
			role: .user,
			modifiedAt: .distantPast,
			value: "payload"
		)))

		let duplicated = try await library.duplicate(source, named: "Copy")
		let duplicate = try #require(duplicated)
		#expect(duplicate.id != source.id)
		#expect(duplicate.name == "Copy")
		#expect(duplicate.role == .user)
		#expect(duplicate.snapshot.value == source.snapshot.value)
		#expect(library.packageURL(for: duplicate).map { FileManager.default.fileExists(atPath: $0.path) } == true)

		try await library.delete(source)
		try await library.delete(duplicate)
	}

	@MainActor @Test("Built-in documents remain in memory and are never assigned package URLs")
	func builtInRoleIsNotPersisted() async throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let builtIn = TestDocument(restoring: .init(
			id: "built-in",
			name: "Built In",
			role: .builtIn,
			modifiedAt: .distantPast,
			value: "fixture"
		))
		let library = PackageDocumentLibrary<TestDocument>(builtInDocuments: [builtIn], rootDirectory: root)

		#expect(library.packageURL(for: builtIn) == nil)
		try await library.delete(builtIn)
		#expect(library.document(id: builtIn.id) === builtIn)
		#expect(library.availableDocuments.contains { $0 === builtIn })
	}

	@MainActor @Test("Loading packages materializes canonical live documents")
	func loadAndCanonicalIdentity() async throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let snapshot = Snapshot(
			id: "loaded",
			name: "Loaded",
			role: .user,
			modifiedAt: .distantPast,
			value: "disk"
		)
		let _ = try write(snapshot, root: root)
		let library = PackageDocumentLibrary<TestDocument>(rootDirectory: root)

		try await library.load()
		let first = try #require(try await library.open(id: snapshot.id))
		let second = try #require(try await library.open(id: snapshot.id))
		#expect(first === second)
		#expect(first.snapshot == snapshot)
		#expect(try await library.open(first) === first)

		try await library.delete(first)
	}

	@MainActor @Test("Loaded documents must be activated before edits can save")
	func loadedDocumentRequiresActivation() async throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let snapshot = Snapshot(
			id: "loaded-edit",
			name: "Loaded Edit",
			role: .user,
			modifiedAt: .distantPast,
			value: "disk"
		)
		let url = try write(snapshot, root: root)
		let library = PackageDocumentLibrary<TestDocument>(rootDirectory: root)
		try await library.load()
		let document = try #require(library.document(id: snapshot.id))

		var inactiveError: Error?
		document.snapshot.value = "would-be-lost"
		library.documentDidChange(document) { error in inactiveError = error }
		#expect(inactiveError != nil)

		let active = try await library.open(document)
		#expect(active === document)
		document.snapshot.value = "persisted"
		library.documentDidChange(document) { _ in }
		#expect(library.persistenceState(for: document.id)?.status == .dirty)
		await library.flushAll()
		#expect(library.persistenceState(for: document.id)?.status == .saved)

		let wrapper = try FileWrapper(url: url, options: .immediate)
		let reloaded = try TestDocument.snapshot(from: wrapper)
		#expect(reloaded.value == "persisted")
	}

	@MainActor @Test("Persistence state advances from dirty to saved after an explicit flush")
	func persistenceStateTracksFlush() async throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let library = PackageDocumentLibrary<TestDocument>(rootDirectory: root)
		let document = try await library.createDocument()
		let initial = try #require(library.persistenceState(for: document.id))
		#expect(initial.status == .saved)
		#expect(initial.currentChange == initial.persistedChange)

		document.snapshot.value = "changed"
		library.documentDidChange(document) { _ in }
		let dirty = try #require(library.persistenceState(for: document.id))
		#expect(dirty.status == .dirty)
		#expect(dirty.currentChange > dirty.persistedChange)

		await library.flushAll()
		let saved = try #require(library.persistenceState(for: document.id))
		#expect(saved.status == .saved)
		#expect(saved.currentChange == saved.persistedChange)
		#expect(saved.lastSuccessfulSaveAt != nil)
	}

	@MainActor @Test("Single-document save persists the requested document")
	func singleDocumentSavePersistsRequestedDocument() async throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let library = PackageDocumentLibrary<TestDocument>(rootDirectory: root)
		let first = try await library.createDocument()
		let second = try await library.createDocument()
		TestDocument.persistProbe.reset()

		first.snapshot.value = "first changed"
		library.documentDidChange(first)
		second.snapshot.value = "second changed"
		library.documentDidChange(second)

		try await library.save(first, operation: .documentSwitch)

		#expect(library.persistenceState(for: first.id)?.status == .saved)
		#expect(library.persistenceState(for: second.id)?.status == .dirty)
		#expect(TestDocument.persistProbe.count == 1)
	}

	@MainActor @Test("All-document save barrier persists every dirty active document")
	func allDocumentSaveBarrierPersistsEveryDirtyDocument() async throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let library = PackageDocumentLibrary<TestDocument>(rootDirectory: root)
		let first = try await library.createDocument()
		let second = try await library.createDocument()
		TestDocument.persistProbe.reset()

		first.snapshot.value = "first changed"
		library.documentDidChange(first)
		second.snapshot.value = "second changed"
		library.documentDidChange(second)

		try await library.flushAllRequiringSuccess(operation: .applicationTermination)

		#expect(library.persistenceState(for: first.id)?.status == .saved)
		#expect(library.persistenceState(for: second.id)?.status == .saved)
		#expect(TestDocument.persistProbe.count == 2)
	}

	@MainActor @Test("Concurrent flush requests coalesce and leave the document saved")
	func concurrentFlushesCoalesce() async throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let library = PackageDocumentLibrary<TestDocument>(rootDirectory: root)
		let document = try await library.createDocument()
		TestDocument.persistProbe.reset()

		document.snapshot.value = "changed once"
		library.documentDidChange(document)

		async let first: Void = library.flushAll(operation: .lifecycleFlush)
		async let second: Void = library.flushAll(operation: .lifecycleFlush)
		_ = await (first, second)

		let state = try #require(library.persistenceState(for: document.id))
		#expect(state.status == .saved)
		#expect(state.currentChange == state.persistedChange)
		#expect(TestDocument.persistProbe.count == 1)
	}

	@MainActor @Test("A user document that is not persisted cannot be activated for editing")
	func activationRequiresPersistedBacking() async throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let library = PackageDocumentLibrary<TestDocument>(rootDirectory: root)
		let document = TestDocument(restoring: .init(
			id: "not-persisted",
			name: "Not Persisted",
			role: .user,
			modifiedAt: .now,
			value: "memory only"
		))

		do {
			_ = try await library.open(document)
			Issue.record("Expected activation to fail for a user document with no persisted backing package")
		} catch {
			#expect(error.localizedDescription.contains("Document not found"))
		}
	}

	@MainActor @Test("Adopting persisted state restores an existing live object in place")
	func adoptRestoresCanonicalObject() async throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let library = PackageDocumentLibrary<TestDocument>(rootDirectory: root)
		let original = TestDocument(restoring: .init(
			id: "same-id",
			name: "Original",
			role: .user,
			modifiedAt: .distantPast,
			value: "one"
		))
		let live = try await library.createPersisted(original)
		let replacement = Snapshot(
			id: live.id,
			name: "Replacement",
			role: .user,
			modifiedAt: .now,
			value: "two"
		)

		let adopted = try await library.adoptPersisted(replacement)
		#expect(adopted === live)
		#expect(live.snapshot == replacement)

		try await library.delete(live)
	}

	@MainActor @Test("Import conflict supports replacement and copy identities")
	func importConflictResolution() async throws {
		let root = temporaryDirectory()
		let externalRoot = temporaryDirectory()
		defer {
			try? FileManager.default.removeItem(at: root)
			try? FileManager.default.removeItem(at: externalRoot)
		}
		let library = PackageDocumentLibrary<TestDocument>(rootDirectory: root)
		let existing = TestDocument(restoring: .init(
			id: "conflict-id",
			name: "Existing",
			role: .user,
			modifiedAt: .distantPast,
			value: "old"
		))
		let canonical = try await library.createPersisted(existing)
		let incoming = Snapshot(
			id: canonical.id,
			name: "Incoming",
			role: .user,
			modifiedAt: .now,
			value: "new"
		)
		let externalURL = try write(incoming, root: externalRoot)

		let firstImport = try await library.importDocument(.success(externalURL))
		#expect(firstImport == nil)
		#expect(library.importConflict?.id == canonical.id)
		let resolvedReplacement = try await library.resolveImportConflict(.replaceExisting)
		let replaced = try #require(resolvedReplacement)
		#expect(replaced === canonical)
		#expect(replaced.snapshot.value == "new")

		let newer = Snapshot(
			id: canonical.id,
			name: "Incoming Copy",
			role: .user,
			modifiedAt: .now,
			value: "copy"
		)
		let newerURL = try write(newer, root: externalRoot)
		let secondImport = try await library.importDocument(.success(newerURL))
		#expect(secondImport == nil)
		let resolvedCopy = try await library.resolveImportConflict(.importAsCopy)
		let copy = try #require(resolvedCopy)
		#expect(copy.id != canonical.id)
		#expect(copy.snapshot.value == "copy")

		try await library.delete(canonical)
		try await library.delete(copy)
	}

	@MainActor @Test("Import replaces invalid or built-in identities instead of rejecting user data")
	func importRepairsInvalidAndBuiltInIDs() async throws {
		let root = temporaryDirectory()
		let externalRoot = temporaryDirectory()
		defer {
			try? FileManager.default.removeItem(at: root)
			try? FileManager.default.removeItem(at: externalRoot)
		}

		let builtIn = TestDocument(restoring: .init(
			id: "built-in", name: "Built In", role: .builtIn, modifiedAt: .distantPast, value: "fixture"
		))
		let library = PackageDocumentLibrary<TestDocument>(builtInDocuments: [builtIn], rootDirectory: root)

		let importedURL = try write(.init(
			id: "built-in", name: "User Data", role: .user, modifiedAt: .now, value: "preserve-me"
		), root: externalRoot)
		let imported = try #require(try await library.importDocument(.success(importedURL)))

		#expect(imported.id != "built-in")
		#expect(TestDocument.isValidUserDocumentID(imported.id))
		#expect(imported.snapshot.value == "preserve-me")
		#expect(library.document(id: "built-in") === builtIn)
		let notice = try #require(library.notices.first)
		#expect(notice.kind == .identityRepair)
		library.dismissNotice(id: notice.id)
		#expect(library.notices.isEmpty)
		try await library.delete(imported)
	}

	@MainActor @Test("Import avoids a canonical package-path collision even when it is not cataloged")
	func importAvoidsUncatalogedStorageCollision() async throws {
		let root = temporaryDirectory()
		let externalRoot = temporaryDirectory()
		defer {
			try? FileManager.default.removeItem(at: root)
			try? FileManager.default.removeItem(at: externalRoot)
		}

		let collisionID = "uncataloged-collision"
		let location = TestDocument.storageLocation(fileManager: .default)
		let occupiedURL = location.packageURL(for: collisionID, root: root)
		try FileManager.default.createDirectory(at: occupiedURL, withIntermediateDirectories: true)

		let library = PackageDocumentLibrary<TestDocument>(rootDirectory: root)
		let importedURL = try write(.init(
			id: collisionID, name: "Incoming", role: .user, modifiedAt: .now, value: "safe"
		), root: externalRoot)
		let imported = try #require(try await library.importDocument(.success(importedURL)))

		#expect(imported.id != collisionID)
		#expect(FileManager.default.fileExists(atPath: occupiedURL.path))
		#expect(imported.snapshot.value == "safe")
		try await library.delete(imported)
	}

	@MainActor @Test("Import avoids an ID embedded in a misnamed catalog package")
	func importAvoidsIdentityReservedByMisnamedPackage() async throws {
		let root = temporaryDirectory()
		let externalRoot = temporaryDirectory()
		defer {
			try? FileManager.default.removeItem(at: root)
			try? FileManager.default.removeItem(at: externalRoot)
		}

		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		let reservedID = "reserved-inside-misnamed-package"
		let misnamedURL = root.appendingPathComponent("wrong-name.testpkg", isDirectory: true)
		let misnamedSnapshot = Snapshot(
			id: reservedID,
			name: "Misnamed",
			role: .user,
			modifiedAt: .now,
			value: "existing"
		)
		try TestDocument.fileWrapper(for: misnamedSnapshot).write(to: misnamedURL, options: .atomic, originalContentsURL: nil)

		let library = PackageDocumentLibrary<TestDocument>(rootDirectory: root)
		try await library.load()
		#expect(library.catalogIssues.map(\.packageURL).contains(misnamedURL))

		let importedURL = try write(.init(
			id: reservedID, name: "Incoming", role: .user, modifiedAt: .now, value: "preserve"
		), root: externalRoot)
		let imported = try #require(try await library.importDocument(.success(importedURL)))

		#expect(imported.id != reservedID)
		#expect(imported.snapshot.value == "preserve")
		#expect(FileManager.default.fileExists(atPath: misnamedURL.path))
		try await library.delete(imported)
	}

	@MainActor @Test("Document URLs route to the canonical live document")
	func documentURLRouting() async throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let library = PackageDocumentLibrary<TestDocument>(rootDirectory: root)
		let document = try await library.createDocument()
		let url = try #require(library.url(for: document))

		let routed = try await library.open(url: url)
		let opened = try #require(routed)
		#expect(opened === document)

		try await library.delete(document)
	}

	@MainActor @Test("Package export uses semantic name and exported snapshot policy")
	func packageExport() async throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let library = PackageDocumentLibrary<TestDocument>(rootDirectory: root)
		let builtIn = TestDocument(restoring: .init(
			id: "export-id",
			name: "Export Name",
			role: .builtIn,
			modifiedAt: .distantPast,
			value: "exported"
		))

		let exportedURL = try await library.exportPackage(builtIn)
		defer { try? FileManager.default.removeItem(at: exportedURL) }
		#expect(exportedURL.lastPathComponent == "Export Name.testpkg")
		let wrapper = try FileWrapper(url: exportedURL, options: .immediate)
		let snapshot = try TestDocument.snapshot(from: wrapper)
		#expect(snapshot.role == .user)
		#expect(snapshot.value == "exported")
	}

	private func write(_ snapshot: Snapshot, root: URL) throws -> URL {
		let location = TestDocument.storageLocation(fileManager: .default)
		let url = location.packageURL(for: snapshot.id, root: root)
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		try TestDocument.fileWrapper(for: snapshot).write(to: url, options: .atomic, originalContentsURL: nil)
		return url
	}

	private func temporaryDirectory() -> URL {
		FileManager.default.temporaryDirectory
			.appendingPathComponent("SBJFoundation-PackageDocumentLibraryTests-\(UUID().uuidString)", isDirectory: true)
	}
}
#endif
