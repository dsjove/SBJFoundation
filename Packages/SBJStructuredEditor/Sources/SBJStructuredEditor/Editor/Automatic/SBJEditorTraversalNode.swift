import SBJDataDefinition
import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// One logical field in the traversal, independent of the SwiftUI view used
/// to display that field. Children are intentionally deferred: closed branches
/// do not build descendant nodes.
@MainActor
struct SBJEditorTraversalNode: Identifiable {
    var context: SBJEditTraversalContext
    let name: String
    /// True for compound disclosures, including currently empty collections.
    let isDisclosure: Bool
    private let descend: (SBJEditTraversalContext) -> [SBJEditorTraversalNode]
    private let renderRow: ((SBJEditTraversalContext) -> AnyView)?
    /// Footer decorations assigned by ancestor groups, deepest first.
    /// A divider is part of the final visible row, not a separate hierarchy node.
    var endDividerLevels: [Int] = []
    private let includeRow: (SBJStructuralSearchCriteria) -> Bool

	nonisolated var id: SBJEditorItemIdentifier { context.itemIdentifier }
    var depth: Int { context.treeLevel }
    var disclosureMode: SBJPresentationDisclosureMode { context.branch.disclosureMode }

    init(
        context: SBJEditTraversalContext,
        name: String,
        disclosureMode: SBJPresentationDisclosureMode? = nil,
        isDisclosure: Bool = false,
        render: ((SBJEditTraversalContext) -> AnyView)? = nil,
        isIncluded: @escaping (SBJStructuralSearchCriteria) -> Bool = { _ in true },
        children: @escaping (SBJEditTraversalContext) -> [SBJEditorTraversalNode] = { _ in [] }
    ) {
        self.context = context.withBranch(context.branch.withDisclosureMode(disclosureMode ?? context.branch.disclosureMode))
        self.name = name
        self.isDisclosure = isDisclosure
        self.descend = children
        self.renderRow = render
        self.includeRow = isIncluded
    }

    func children() -> [SBJEditorTraversalNode] { descend(context) }

    func renderedRow() -> AnyView? { renderRow?(context) }

    func isIncluded(in criteria: SBJStructuralSearchCriteria) -> Bool { includeRow(criteria) }


}

/// Projects the currently exposed hierarchy without constructing descendant views.
/// Disclosure preferences remain separate from transient search/navigation expansion.
@MainActor
func sbjEditorRows(
    roots: [SBJEditorTraversalNode],
    presentationModel: SBJEditorPresentationModel,
    temporarilyExpanded: (SBJEditorTraversalNode) -> Bool = { _ in false }
) -> [SBJEditorTraversalNode] {
    // Filtering is a property of the complete model subtree, not merely of
    // currently exposed rows. In particular, a changed descendant must not be
    // discarded because its parent does not independently match the filter.
    func project(
        _ candidate: SBJEditorTraversalNode,
        criteria: SBJStructuralSearchCriteria,
        expectedLevel: Int
    ) -> [SBJEditorTraversalNode] {
        var node = candidate
        node.context = node.context.atTreeLevel(expectedLevel)
        let navigationMatch = presentationModel.navigationTarget?.contains(node.context.navigationPath) == true
        let directlyIncluded = navigationMatch || node.isIncluded(in: criteria)
        let searchExpansion = criteria.forcesExpansion(hasContent: nil)
        let navigationExpansion = navigationMatch
        let isExpanded = presentationModel.resolved(
            node.id,
            mode: node.disclosureMode,
            search: searchExpansion || temporarilyExpanded(node),
            navigation: navigationExpansion
        )

        var descendants: [SBJEditorTraversalNode] = []
        var hadChildren = false
        if isExpanded {
            let childCriteria = criteria.descendingPastMatchedLabel(node.name)
            let children = node.children()
            hadChildren = !children.isEmpty
            for child in children {
                descendants.append(contentsOf: project(
                    child, criteria: childCriteria,
                    expectedLevel: node.context.treeLevel + 1
                ))
            }
        }

        // Neither a mismatching ancestor nor a matching descendant can be
        // decided upon in isolation. Preserve the ancestor as the path to any
        // matching descendants; no extra SwiftUI view hierarchy is constructed.
        guard directlyIncluded || !descendants.isEmpty else { return [] }
        node.context = node.context.withBranch(node.context.branch.withSearchCriteria(criteria))
        var result = [node]
        result.append(contentsOf: descendants)
        if isExpanded && (node.isDisclosure || hadChildren) {
            result[result.count - 1].endDividerLevels.append(node.context.treeLevel + 1)
        }
        return result
    }

    return roots.flatMap { root in
        project(root, criteria: presentationModel.searchCriteria,
                expectedLevel: root.context.treeLevel)
    }
}

#endif
