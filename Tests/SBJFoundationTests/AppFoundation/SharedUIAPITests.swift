import SBJUIVocabulary
import Foundation
import SBJDataDefinition
import SwiftUI
import Testing
import SBJLocalization
@testable import SBJFoundation

@Suite("Shared UI API")
struct SharedUIAPITests {
    @MainActor
    @Test func imageReferenceInitializersRetainEstablishedSurface() {
        _ = Image(.system("star"))
        _ = Image(.asset("logo"))
        _ = Image(.asset("logo", bundle: Bundle.main))
        _ = Image(.resource("ThumbnailDocument.png"))
        _ = Image(.resource(name: "ThumbnailDocument", extension: "png", bundle: Bundle.main))
        _ = Image(.file(URL(fileURLWithPath: "/tmp/image.png")))
        _ = Label("Favorite", image: .system("star"))
        _ = Label("Portrait", image: .file(URL(fileURLWithPath: "/tmp/image.png")))
    }

    @MainActor
    @Test func applyIfRetainsEstablishedSurface() {
        _ = Text("Value").applyIf("Label") { view, label in
            view.accessibilityLabel(label)
        }
    }

    @MainActor
    @Test func pendingAlertViewModifierRetainsEstablishedSurface() {
        _ = Text("Value").pendingAlert(Binding<PendingAlert?>.constant(nil))
    }

    @MainActor
    @Test func accessibleViewModifierRetainsEstablishedSurface() {
        let item: any Accessible = AccessibleItem(
            label: "Name",
            hint: "Enter a name",
            value: "Current"
        )
        _ = Text("Name").accessibility(item)
        _ = Text("Name").accessibility(label: "Name", hint: "Hint", value: "Value")
    }

    @MainActor
    @Test func selectionHighlightViewModifierRetainsEstablishedSurface() {
        _ = Text("Value").sbjSelectionHighlight()
        _ = Text("Value").sbjSelectionHighlight(
            true,
            emphasis: .transient,
            cornerRadius: SBJUIAppearance.transientSelectionCornerRadius
        )

        func requireSendable<T: Sendable>(_: T) {}
        requireSendable(SBJSelectionHighlightEmphasis.selection)
        requireSendable(SBJSelectionHighlightEmphasis.transient)
    }
}
