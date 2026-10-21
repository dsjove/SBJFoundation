import SwiftUI
import Testing
@testable import SBJUIVocabulary

@Suite("Conditional view application")
struct ViewApplyIfTests {
    @MainActor
    @Test func applyIfRetainsEstablishedSurface() {
        _ = Text("Value").applyIf("Label") { view, label in
            view.accessibilityLabel(label)
        }
    }
}
