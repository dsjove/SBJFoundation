import Foundation
import Testing
import UniformTypeIdentifiers
@testable import SBJFileResources

@Suite("SBJResourceContent storage")
struct SBJResourceContentStorageTests {
    @Test("regular file wrappers round-trip as regular files")
    func regularFileRoundTrip() throws {
        let bytes = Data("hello".utf8)
        let wrapper = FileWrapper(regularFileWithContents: bytes)

        let content = try #require(
            SBJResourceContent(
                storageFileWrapper: wrapper,
                filename: "note.txt"
            )
        )

        #expect(content.storageRepresentation == .regularFile)
        #expect(content.data == bytes)
        #expect(content.storageFileWrapper().isRegularFile)
        #expect(try content.storageFileWrapper().sbjRegularFileContents() == bytes)
    }

    @Test("directory wrappers round-trip even when their UTType is unknown")
    func unknownDirectoryRoundTrip() throws {
        let original = FileWrapper(directoryWithFileWrappers: [
            "manifest.json": FileWrapper(regularFileWithContents: Data("{}".utf8)),
            "Nested": FileWrapper(directoryWithFileWrappers: [
                "payload.bin": FileWrapper(regularFileWithContents: Data([1, 2, 3]))
            ])
        ])

        // Deliberately use an extension with no package semantics. Shape must come from disk,
        // not from UTType registration.
        let content = try #require(
            SBJResourceContent(
                storageFileWrapper: original,
                filename: "attachment.unknown-sbj-package",
                fallbackContentType: .data
            )
        )

        #expect(content.storageRepresentation == .directory)
        #expect(content.contentType.conforms(to: .package))

        let restored = content.storageFileWrapper()
        #expect(restored.isDirectory)
        let root = try restored.sbjDirectoryContents()
        #expect(try root["manifest.json"]?.sbjRegularFileContents() == Data("{}".utf8))
        let nested = try #require(root["Nested"])
        let nestedChildren = try nested.sbjDirectoryContents()
        #expect(try nestedChildren["payload.bin"]?.sbjRegularFileContents() == Data([1, 2, 3]))
    }

    @Test("validated accessors reject the wrong wrapper kind with Swift errors")
    func validatedAccessorsRejectWrongKinds() throws {
        let regular = FileWrapper(regularFileWithContents: Data())
        let directory = FileWrapper(directoryWithFileWrappers: [:])

        #expect(throws: SBJFileWrapperReadError.self) {
            _ = try directory.sbjRegularFileContents()
        }
        #expect(throws: SBJFileWrapperReadError.self) {
            _ = try regular.sbjDirectoryContents()
        }
    }
}
