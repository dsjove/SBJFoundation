import Foundation
import Testing
import SBJDataDefinition
@testable import SBJImage
import SBJUIVocabulary

@Suite("Image references")
struct ImageReferenceTests {
    @Test func emptyStateMatchesOriginalSemantics() {
        #expect(ImageReference.none.isEmpty)
        #expect(ImageReference.system("").isEmpty)
        #expect(ImageReference.asset("").isEmpty)
        #expect(!ImageReference.system("info.circle").isEmpty)
        #expect(!ImageReference.asset("logo").isEmpty)
        #expect(!ImageReference.resource("ThumbnailDocument.png").isEmpty)
        #expect(!ImageReference.file(URL(fileURLWithPath: "/tmp/image.png")).isEmpty)
    }

    @Test func presentationImageReferencesAreSendable() {
        func requireSendable<T: Sendable>(_: T) {}
        requireSendable(ImageReference.system("star"))
        requireSendable(ImageReference.asset("logo", bundle: Bundle.main))
        requireSendable(ImageReference.file(URL(fileURLWithPath: "/tmp/image.png")))
        requireSendable(Bundle.main)
    }
}
