import SBJDataDefinition
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Projects structural collection mutations into live SwiftUI row actions.
/// Array mutation and bounds checking live in SBJDataDefinition.
@MainActor
enum SBJArrayElementActions {
    static func make<Element>(
        parent: Binding<[Element]>, index: Int, count: Int,
        canReorder: Bool, resolvedIndex: @escaping () -> Int?
    ) -> SBJEditorItemActions {
        SBJEditorItemActions(
            remove: {
                guard let position = resolvedIndex() else { return }
                var values = parent.wrappedValue
                guard SBJArrayMutation.remove(at: position, from: &values) else { return }
                parent.wrappedValue = values
            },
            moveUp: canReorder && index > 0 ? {
                guard let position = resolvedIndex() else { return }
                var values = parent.wrappedValue
                guard SBJArrayMutation.move(from: position, to: position - 1, in: &values) else { return }
                parent.wrappedValue = values
            } : nil,
            moveDown: canReorder && index < count - 1 ? {
                guard let position = resolvedIndex() else { return }
                var values = parent.wrappedValue
                guard SBJArrayMutation.move(from: position, to: position + 1, in: &values) else { return }
                parent.wrappedValue = values
            } : nil
        )
    }
}
#endif
