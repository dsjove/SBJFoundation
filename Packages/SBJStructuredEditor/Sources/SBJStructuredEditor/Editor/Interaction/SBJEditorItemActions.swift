import SBJUIVocabulary
import SBJUnits
#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

@MainActor
private struct SBJEditorActionHeight<Content: View>: View {
    @Environment(SBJEditorPresentationModel.self) private var presentationModel: SBJEditorPresentationModel?
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(minHeight: presentationModel?.formattingOptions.firstLineMinimumHeight ?? 28, alignment: .center)
    }
}

@MainActor
struct SBJEditorItemActions {
    let remove: () -> Void
    let moveUp: (() -> Void)?
    let moveDown: (() -> Void)?

    var leadingView: AnyView {
        AnyView(
            SBJEditorActionHeight {
                SBJRemoveButton(
                    accessibilityLabel: "Remove item",
                    accessibilityHint: "Removes this item from the collection",
                    action: remove
                )
            }
            .frame(minWidth: 22, alignment: .center)
        )
    }

    var trailingView: AnyView {
        guard moveUp != nil || moveDown != nil else {
            return AnyView(EmptyView())
        }
        return AnyView(
            SBJEditorActionHeight {
                HStack(spacing: 6) {
                    SBJMoveButton(
                    .up,
                    accessibilityLabel: "Move item up",
                    accessibilityHint: "Moves this item one position earlier",
                    action: moveUp
                )

                SBJMoveButton(
                    .down,
                    accessibilityLabel: "Move item down",
                    accessibilityHint: "Moves this item one position later",
                    action: moveDown
                )
            }
            }
        )
    }
}

@MainActor
final class SBJEditorFocusRequest {
    private var claimed = false

    func claim() -> Bool {
        guard !claimed else { return false }
        claimed = true
        return true
    }

    func claim(_ focus: FocusState<Bool>.Binding) {
        if claim() { focus.wrappedValue = true }
    }
}
#endif
