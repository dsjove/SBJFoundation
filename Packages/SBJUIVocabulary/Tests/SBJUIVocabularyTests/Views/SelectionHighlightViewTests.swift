import SwiftUI
import Testing
@testable import SBJUIVocabulary

@Suite("Selection highlight")
struct SelectionHighlightViewTests {
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
