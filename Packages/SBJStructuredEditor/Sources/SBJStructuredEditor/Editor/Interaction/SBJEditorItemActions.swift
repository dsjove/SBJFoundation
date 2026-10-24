import SBJUIVocabulary
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

    // Collection elements do not have their own compile-time property info.
    // Use the shared information gutter for removal instead of a leading lane.
    var infoLaneView: AnyView {
        AnyView(
            SBJEditorActionHeight {
                SBJConfirmedRemoveButton(
                    accessibilityLabel: "Remove item",
                    remove: remove
                )
            }
        )
    }

    var leadingView: AnyView { AnyView(EmptyView()) }

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
