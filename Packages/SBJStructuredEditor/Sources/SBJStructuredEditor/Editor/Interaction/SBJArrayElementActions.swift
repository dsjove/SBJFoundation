import SBJStructure
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Projects structural collection mutations into live SwiftUI row actions.
/// Array mutation and bounds checking live in SBJStructure.
@MainActor
enum SBJArrayElementActions {
    static func make<Element>(
        parent: Binding<[Element]>, index: Int, count: Int,
        canReorder: Bool, canRemove: Bool = true, resolvedIndex: @escaping () -> Int?
    ) -> SBJEditorItemActions {
        SBJEditorItemActions(
            remove: canRemove ? {
                guard let position = resolvedIndex() else { return }
                var values = parent.wrappedValue
                guard SBJArrayMutation.remove(at: position, from: &values) else { return }
                parent.wrappedValue = values
            } : nil,
            moveUp: canReorder && index > 0 ? {
                guard let position = resolvedIndex() else { return }
                var values = parent.wrappedValue
                // The row can move after its buttons were constructed.
                guard position > 0, values.indices.contains(position) else { return }
                guard SBJArrayMutation.move(from: position, to: position - 1, in: &values) else { return }
                parent.wrappedValue = values
            } : nil,
            moveDown: canReorder && index < count - 1 ? {
                guard let position = resolvedIndex() else { return }
                var values = parent.wrappedValue
                // Use the current collection bounds, not the row's original count.
                guard position >= 0, position < values.count - 1 else { return }
                guard SBJArrayMutation.move(from: position, to: position + 1, in: &values) else { return }
                parent.wrappedValue = values
            } : nil
        )
    }
}
#endif
