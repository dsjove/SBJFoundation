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
}
