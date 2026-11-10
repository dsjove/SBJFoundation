import Foundation
import Testing
import UniformTypeIdentifiers
@testable import SBJFileResources

struct URLMediaClassificationTests {
    @Test func genericTypeClassification() {
        #expect(UTType.movie.isMovieMedia)
        #expect(UTType.image.isImageMedia)
        #expect(UTType.audio.isAudioMedia)
        #expect(!UTType.plainText.isMovieMedia)
    }

    @Test func validWebLinkReturnsDestination() throws {
        let folder = FileManager.default.temporaryDirectory
        let file = folder.appendingPathComponent(UUID().uuidString + ".webloc")
        defer { try? FileManager.default.removeItem(at: file) }
        let plist = ["URL": "https://example.org/video"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: file)
        #expect(try file.readWebLink().absoluteString == "https://example.org/video")
    }

    @Test func invalidWebLinkIsRejected() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".webloc")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("not a plist".utf8).write(to: file)
        #expect(throws: WebLinkError.self) { try file.readWebLink() }
    }
}
