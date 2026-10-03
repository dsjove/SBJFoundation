#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

@MainActor
struct SBJEditorItemActions {
    let remove: () -> Void
    let moveUp: (() -> Void)?
    let moveDown: (() -> Void)?

    var leadingView: AnyView {
        AnyView(
            SBJRemoveButton(
                accessibilityLabel: "Remove item",
                accessibilityHint: "Removes this item from the collection",
                action: remove
            )
            .frame(minWidth: 22, minHeight: SBJEditorRowMetrics.firstLineMinimumHeight, alignment: .center)
        )
    }

    var trailingView: AnyView {
        guard moveUp != nil || moveDown != nil else {
            return AnyView(EmptyView())
        }
        return AnyView(
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
            .frame(minHeight: SBJEditorRowMetrics.firstLineMinimumHeight, alignment: .center)
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
