#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Render-independent identity and location of an exposed editor field.
/// This descriptor does not instantiate a SwiftUI field/control.
@MainActor
struct SBJEditorPresentationRow<Content>: Identifiable {
    let context: SBJEditTraversalContext
    let content: Content

    var id: SBJEditorItemIdentifier { context.itemIdentifier }
    var depth: Int { context.treeLevel }
}

/// Converts a snapshot into presentation rows without constructing controls.
/// Build 2 uses this boundary for root, object, collection, and associated-enum
/// sibling rows. Compound descendants still need a separate traversal contract.
@MainActor
func sbjEditorPresentationRows<Content>(
    from snapshot: [SBJEditorSnapshotItem<Content>],
    parent: SBJEditTraversalContext,
    navigationPath: (Content) -> String,
    depthIncrement: Int
) -> [SBJEditorPresentationRow<Content>] {
    snapshot.map { item in
        SBJEditorPresentationRow(
            context: SBJEditTraversalContext(
                treeLevel: parent.treeLevel + depthIncrement,
                itemIdentifier: item.itemIdentifier,
                indexPath: item.indexPath,
                navigationPath: parent.navigationPath + [navigationPath(item.content)]
            ),
            content: item.content
        )
    }
}
#endif
