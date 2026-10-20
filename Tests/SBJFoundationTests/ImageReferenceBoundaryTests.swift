import Foundation
import Testing
import SBJDataDefinition
@testable import SBJFoundation
import SBJUIVocabulary

@Suite("Image reference source boundaries")
struct ImageReferenceBoundaryTests {
    @Test("Symbolic sources remain within SBJSymbol")
    func symbols() {
        #expect(ImageReference.symbol(.system("plus")) == .system("plus"))
        #expect(ImageReference.asset("Tools").isEmpty == false)
        #expect(ImageReference.resource("preview.png").isEmpty == false)
        #expect(ImageReference.symbol(.system("")).isEmpty)
    }

    @Test("File references remain unchanged for image documents and images")
    func files() {
        let image = URL(fileURLWithPath: "/tmp/example.png")
        let document = URL(fileURLWithPath: "/tmp/example.sbjimage")
        #expect(ImageReference.file(image) != .file(document))
        #expect(!ImageReference.file(document).isEmpty)
    }

    @Test("Referenced content occurrence retains source path")
    func contentOccurrence() {
        let id = SBJReferencedContentID("portrait")
        #expect(SBJReferencedContentOccurrence(id: id, path: "portrait").id == id)
    }
}
