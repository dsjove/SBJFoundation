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

	@Test("Skips active package IDs during catalog rescans")
	func excludesActivePackages() throws {
		let root = temporaryDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		try write(.init(id: "one", value: "First"), root: root)
		try write(.init(id: "two", value: "Second"), root: root)

		let store = makeStore(root: root)
		#expect(try store.scanCatalog(excludingIDs: ["one"]).states == [
			.init(id: "two", value: "Second"),
		])
	}

	private func makeStore(root: URL) -> PackageLibraryStore<String, Fixture> {
		PackageLibraryStore(
			directory: root,
			packageURL: { root.appendingPathComponent("\($0).pkg", isDirectory: true) },
			identifier: { $0.id },
			loadPackage: { directory in
				let text = try String(contentsOf: directory.appendingPathComponent("state.txt"), encoding: .utf8)
				let pieces = text.split(separator: "|", maxSplits: 1).map(String.init)
				guard pieces.count == 2 else { throw CocoaError(.fileReadCorruptFile) }
				return Fixture(id: pieces[0], value: pieces[1])
			}
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
