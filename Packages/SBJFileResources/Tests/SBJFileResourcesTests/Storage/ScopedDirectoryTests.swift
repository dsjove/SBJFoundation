import Foundation
import Testing
@testable import SBJFileResources

@Suite("Directory-relative scoped file resources")
struct ScopedFileTests {
    @Test("Derives the path from the authorized root")
    func relativePaths() throws {
        let directory = ScopedDirectory(URL(fileURLWithPath: "/Volumes/Movies", isDirectory: true))
        let file = try directory.file(at: "Dramas/Example.mp4")
        #expect(file.relativePath == "Dramas/Example.mp4")
        #expect(file.url.path == "/Volumes/Movies/Dramas/Example.mp4")
        #expect(try directory.file(at: file.url).relativePath == file.relativePath)
    }

    @Test("Rejects paths outside the selected directory")
    func invalidPaths() {
        let directory = ScopedDirectory(URL(fileURLWithPath: "/Volumes/Movies", isDirectory: true))
        #expect(throws: ScopedFileError.self) { try directory.file(at: "../Private.mp4") }
        #expect(throws: ScopedFileError.self) { try directory.file(at: "/tmp/Private.mp4") }
        #expect(throws: ScopedFileError.self) { try directory.file(at: "sub//Movie.mp4") }
        #expect(throws: ScopedFileError.self) { try directory.file(at: "sub/./Movie.mp4") }
        #expect(throws: ScopedFileError.self) {
            try directory.file(at: URL(fileURLWithPath: "/Volumes/Other/Movie.mp4"))
        }
    }

    @Test("A sibling prefix is not part of the authorized root")
    func siblingPrefix() {
        let directory = ScopedDirectory(URL(fileURLWithPath: "/Volumes/Movies", isDirectory: true))
        #expect(throws: ScopedFileError.self) {
            try directory.file(at: URL(fileURLWithPath: "/Volumes/Movies2/Movie.mp4"))
        }
    }

    @Test("Rejects a symbolic link escaping the authorized root")
    func symlinkEscape() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScopedDirectory-\(UUID().uuidString)", isDirectory: true)
        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScopedOutside-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        // checkedURL() resolves existing filesystem entries; create the target first.
        try Data("private".utf8).write(to: outside.appendingPathComponent("private.txt"))
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("escape"), withDestinationURL: outside
        )
        let scoped = try ScopedDirectory(root).file(at: "escape/private.txt")
        #expect(throws: ScopedFileError.self) { try scoped.checkedURL() }
    }

}
