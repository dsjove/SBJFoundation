import Foundation
import Testing
@testable import SBJDocuments

@Suite("Package resource preservation")
struct PackageResourceDirectoryTests {
    @Test("Replacing copied resources keeps the new tree and no staging directories")
    func replacementPreservesCompleteDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SBJDocuments-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("new".utf8).write(to: source.appendingPathComponent("new.dat"))
        try Data("old".utf8).write(to: destination.appendingPathComponent("old.dat"))

        let warnings = PackageResourceDirectory.copyIfPresent(
            from: source, to: destination,
            resourceDescription: "attachments",
            primaryDataDescription: "document saved"
        )
        #expect(warnings.isEmpty)
        #expect(try Data(contentsOf: destination.appendingPathComponent("new.dat")) == Data("new".utf8))
        #expect(!FileManager.default.fileExists(atPath: destination.appendingPathComponent("old.dat").path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == ["destination", "source"])
    }

    @Test("Copying resources onto themselves leaves their contents intact")
    func sameSourceAndDestinationDoesNotDeleteData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SBJDocuments-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("content.dat")
        try Data("keep".utf8).write(to: file)
        let warnings = PackageResourceDirectory.copyIfPresent(
            from: directory, to: directory,
            resourceDescription: "attachments",
            primaryDataDescription: "document saved"
        )
        #expect(warnings.isEmpty)
        #expect(try Data(contentsOf: file) == Data("keep".utf8))
    }
}
