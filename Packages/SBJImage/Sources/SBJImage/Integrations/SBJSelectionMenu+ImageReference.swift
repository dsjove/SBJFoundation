import SwiftUI
import SBJUIVocabulary

// ImageReference is Foundation-owned; keep this overload outside SBJUIVocabulary.
public extension SBJSelectionMenu {
    init(
        _ title: LocalizedStringKey,
        image: ImageReference,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(content: content) {
            Label(title, image: image)
        }
    }
}
