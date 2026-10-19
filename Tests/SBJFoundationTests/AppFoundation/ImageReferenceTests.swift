import Foundation
import SBJDataDefinition
import Testing
import SBJLocalization
@testable import SBJFoundation

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

    @Test func accessibleImageItemRetainsOriginalAccessibilityBehavior() {
        let decorative = AccessibleImageItem(image: .system("star"), label: "Favorite")
        #expect(decorative.accessibilityLabel == nil)
        #expect(!decorative.labeled)

        #expect(decorative.accessibility.isEmpty)
        let labeled = AccessibleImageItem(image: .system("star"), labeled: true, label: "Favorite")
        #expect(labeled.accessibility == AccessibleItem(label: "Favorite"))
        #expect(labeled.accessibilityLabel == "Favorite")
        #expect(labeled.labeled)
    }

    @Test func presentationImageReferencesAreSendable() {
        func requireSendable<T: Sendable>(_: T) {}
        requireSendable(ImageReference.system("star"))
        requireSendable(ImageReference.asset("logo", bundle: Bundle.main))
        requireSendable(ImageReference.file(URL(fileURLWithPath: "/tmp/image.png")))
        requireSendable(Bundle.main)
    }
}
