import Foundation
import Testing
import UniformTypeIdentifiers
@testable import SBJFoundation

@Suite("Package attachment storage")
struct PackageAttachmentStoreTests {
    @Test("attachments preserve filenames and package shape")
    func roundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let regular = SBJResourceContent(data: Data("hello".utf8), contentType: .plainText)
        let packageWrapper = FileWrapper(directoryWithFileWrappers: [
            "manifest.json": FileWrapper(regularFileWithContents: Data("{}".utf8))
        ])
        let package = try #require(
            SBJResourceContent(storageFileWrapper: packageWrapper, filename: "nested.pkg")
        )

        let warnings = PackageAttachmentStore.replaceAll(
            in: directory,
            attachments: ["note.txt": regular, "nested.pkg": package],
            primaryDataDescription: "Primary data was saved"
        )
        #expect(warnings.isEmpty)

        let loaded = PackageAttachmentStore.load(from: directory)
        #expect(loaded["note.txt"]?.data == regular.data)
        #expect(loaded["nested.pkg"]?.storageRepresentation == .directory)
    }

    @Test("invalid attachment names are rejected without deleting existing attachments")
    func invalidReplacementPreservesExisting() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let existing = SBJResourceContent(data: Data("existing".utf8), contentType: .plainText)
        #expect(PackageAttachmentStore.replaceAll(
            in: directory,
            attachments: ["existing.txt": existing],
            primaryDataDescription: "Primary data was saved"
        ).isEmpty)

        let replacement = SBJResourceContent(data: Data("replacement".utf8), contentType: .plainText)
        let warnings = PackageAttachmentStore.replaceAll(
            in: directory,
            attachments: ["bad/name.txt": replacement],
            primaryDataDescription: "Primary data was saved"
        )

        #expect(!warnings.isEmpty)
        #expect(PackageAttachmentStore.load(from: directory)["existing.txt"]?.data == existing.data)
    }
}
