import Foundation
import Testing
@testable import SBJFoundation

@Suite("Package library catalog")
struct PackageLibraryStoreTests {
	private struct Fixture: Equatable, Sendable {
		let id: String
		let value: String
	}

	@Test("Discovers canonical packages and ignores unrelated directories")
	func discoversCanonicalPackages() throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		try write(.init(id: "two", value: "Second"), root: root)
		try write(.init(id: "one", value: "First"), root: root)
		try FileManager.default.createDirectory(at: root.appendingPathComponent("unrelated.pkg"), withIntermediateDirectories: true)
		try Data("junk".utf8).write(to: root.appendingPathComponent("unrelated.pkg/state.txt"))

		let store = makeStore(root: root)
		#expect(try store.scanCatalog().states == [
			.init(id: "one", value: "First"),
			.init(id: "two", value: "Second"),
		])
	}

	@Test("Unreadable package remains represented as a catalog issue")
	func unreadablePackageRemainsRepresented() throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let broken = root.appendingPathComponent("broken.pkg", isDirectory: true)
		try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)

		let scan = try makeStore(root: root).scanCatalog()

		#expect(scan.presentPackageNames.contains("broken.pkg"))
		#expect(scan.states.isEmpty)
		#expect(scan.issues.count == 1)
		#expect(scan.issues.first?.packageURL == broken)
	}

	@Test("Non-directory package candidate remains represented as a catalog issue")
	func nonDirectoryPackageRemainsRepresented() throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		let broken = root.appendingPathComponent("broken.pkg")
		try Data("not a package".utf8).write(to: broken)

		let scan = try makeStore(root: root).scanCatalog()

		#expect(scan.presentPackageNames == ["broken.pkg"])
		#expect(scan.occupiedPackageNames == ["broken.pkg"])
		#expect(scan.states.isEmpty)
		#expect(scan.issues.count == 1)
		#expect(scan.issues.first?.packageURL == broken)
	}

	@Test("Misnamed decodable package reserves both its actual and canonical package names")
	func misnamedPackageReservesEmbeddedIdentity() throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let wrong = root.appendingPathComponent("wrong.pkg", isDirectory: true)
		try FileManager.default.createDirectory(at: wrong, withIntermediateDirectories: true)
		try Data("one|First".utf8).write(to: wrong.appendingPathComponent("state.txt"))

		let scan = try makeStore(root: root).scanCatalog()

		#expect(scan.presentPackageNames == ["wrong.pkg"])
		#expect(scan.occupiedPackageNames == ["wrong.pkg", "one.pkg"])
		#expect(scan.states.isEmpty)
		#expect(scan.issues.count == 1)
	}

	@Test("Skips active package IDs during catalog rescans")
	func excludesActivePackages() throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		try write(.init(id: "one", value: "First"), root: root)
		try write(.init(id: "two", value: "Second"), root: root)

		let store = makeStore(root: root)
		let scan = try store.scanCatalog(excludingIDs: ["one"])
		#expect(scan.states == [
			.init(id: "two", value: "Second"),
		])
		#expect(scan.presentPackageNames == ["one.pkg", "two.pkg"])
		#expect(scan.occupiedPackageNames == ["one.pkg", "two.pkg"])
	}

	@Test("Metadata catalog keeps unavailable packages present")
	func metadataCatalogKeepsUnavailablePackagesPresent() throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		try write(.init(id: "one", value: "First"), root: root)

		let available = root.appendingPathComponent("one.pkg", isDirectory: true)
		let unavailable = root.appendingPathComponent("cloud-only.pkg", isDirectory: true)
		let scan = makeStore(root: root).scanCatalog(packageURLs: [available, unavailable])

		#expect(scan.states == [.init(id: "one", value: "First")])
		#expect(scan.presentPackageNames == ["one.pkg", "cloud-only.pkg"])
		#expect(scan.occupiedPackageNames == ["one.pkg", "cloud-only.pkg"])
		#expect(scan.unavailablePackageURLs == [unavailable])
		#expect(scan.issues.map(\.packageURL) == [unavailable])
	}


	@Test("Move to trash removes intact package from live catalog")
	func moveToTrashRemovesPackageFromCatalog() throws {
		let root = temporaryDirectory()
		let trash = root.deletingLastPathComponent().appendingPathComponent(".\(root.lastPathComponent)-Trash", isDirectory: true)
		defer {
			try? FileManager.default.removeItem(at: root)
			try? FileManager.default.removeItem(at: trash)
		}
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		try write(.init(id: "one", value: "First"), root: root)

		let store = makeStore(root: root)
		store.moveToTrash(id: "one")

		#expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("one.pkg").path))
		#expect(try FileManager.default.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil).count == 1)
		#expect(try store.scanCatalog().states.isEmpty)
	}

	@Test("Empty trash removes packages and rogue hidden files")
	func emptyTrashRemovesEverything() throws {
		let root = temporaryDirectory()
		let trash = root.deletingLastPathComponent().appendingPathComponent(".\(root.lastPathComponent)-Trash", isDirectory: true)
		defer {
			try? FileManager.default.removeItem(at: root)
			try? FileManager.default.removeItem(at: trash)
		}
		try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
		try Data("rogue".utf8).write(to: trash.appendingPathComponent(".rogue"))
		try FileManager.default.createDirectory(at: trash.appendingPathComponent("leftover.pkg"), withIntermediateDirectories: true)

		let store = makeStore(root: root)
		try store.emptyTrash()

		#expect(try FileManager.default.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil).isEmpty)
	}


	private func makeStore(root: URL) -> PackageLibraryStore<String, Fixture> {
		PackageLibraryStore(
			directory: root,
			trashDirectory: root.deletingLastPathComponent().appendingPathComponent(".\(root.lastPathComponent)-Trash", isDirectory: true),
			packageURL: { root.appendingPathComponent("\($0).pkg", isDirectory: true) },
			identifier: { $0.id },
			loadPackage: { directory in
				let text = try String(contentsOf: directory.appendingPathComponent("state.txt"), encoding: .utf8)
				let pieces = text.split(separator: "|", maxSplits: 1).map(String.init)
				guard pieces.count == 2 else { throw CocoaError(.fileReadCorruptFile) }
				return Fixture(id: pieces[0], value: pieces[1])
			},
			isPackageCandidate: { $0.pathExtension == "pkg" }
		)
	}

	private func write(_ fixture: Fixture, root: URL) throws {
		let directory = root.appendingPathComponent("\(fixture.id).pkg", isDirectory: true)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		try Data("\(fixture.id)|\(fixture.value)".utf8).write(to: directory.appendingPathComponent("state.txt"))
	}

	private func temporaryDirectory() -> URL {
		FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
	}
}

@Suite("Package storage location")
struct PackageStorageLocationTests {
	@Test("String IDs use stable filesystem-safe package names")
	func stringIDPackageNames() {
		let location = PackageStorageLocation<String>(directoryName: "Documents", packageExtension: "example")
		let first = location.packageName(for: "document/id")
		let second = location.packageName(for: "document/id")

		#expect(first == second)
		#expect(first.hasPrefix("id-"))
		#expect(first.hasSuffix(".example"))
		#expect(!first.contains("/"))
	}

	@Test("Custom ID types can supply their own storage component")
	func customIDStorageComponent() {
		let root = FileManager.default.temporaryDirectory.appendingPathComponent("PackageStorageLocationTests", isDirectory: true)
		let location = PackageStorageLocation<Int>(
			directoryName: "Items",
			packageExtension: "pkg",
			storageComponent: { "item-\($0)" }
		)

		#expect(location.packageURL(for: 42, root: root).lastPathComponent == "item-42.pkg")
	}
}
