#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// One logical field in the traversal, independent of the SwiftUI view used
/// to display that field. Children are intentionally deferred: closed branches
/// do not build descendant nodes.
@MainActor
struct SBJEditorTraversalNode: Identifiable {
    let context: SBJEditTraversalContext
    let name: String
    let disclosureMode: SBJEditorDisclosureMode
    private let descend: () -> [SBJEditorTraversalNode]
    private let renderRow: (() -> AnyView)?
    private let includeRow: (SBJEditSearchCriteria) -> Bool

    /// Whether the current row factory renders only this row, or still renders
    /// a recursive subtree. Build 3 must provide a header-only adapter before
    /// independently projecting children of a recursive container.
    enum RenderingScope: Equatable {
        case recursive
        case atomic
    }
    let renderingScope: RenderingScope

    var id: SBJEditorItemIdentifier { context.itemIdentifier }
    var depth: Int { context.treeLevel }

    init(
        context: SBJEditTraversalContext,
        name: String,
        disclosureMode: SBJEditorDisclosureMode = .closed,
        render: (() -> AnyView)? = nil,
        renderingScope: RenderingScope = .recursive,
        isIncluded: @escaping (SBJEditSearchCriteria) -> Bool = { _ in true },
        children: @escaping () -> [SBJEditorTraversalNode] = { [] }
    ) {
        self.context = context
        self.name = name
        self.disclosureMode = disclosureMode
        self.descend = children
        self.renderRow = render
        self.renderingScope = renderingScope
        self.includeRow = isIncluded
    }

    func children() -> [SBJEditorTraversalNode] { descend() }

    /// Only binding-backed nodes can render independently. Snapshot traversal
    /// nodes intentionally do not manufacture read-only bindings.
    var isIndependentlyRenderable: Bool { renderRow != nil }

    func renderedRow() -> AnyView? { renderRow?() }

    /// A node may be traversable without being flat-renderable. In particular,
    /// a recursive editor cannot coexist with independently rendered children.
    var canRenderWithProjectedChildren: Bool {
        isIndependentlyRenderable && renderingScope == .atomic
    }

    func isIncluded(in criteria: SBJEditSearchCriteria) -> Bool { includeRow(criteria) }

    /// Preorder traversal. The expansion predicate is evaluated before
    /// visiting descendants, so a collapsed node never realizes its subtree.
    func appendExposedRows(
        to rows: inout [SBJEditorTraversalNode],
        isExpanded: (SBJEditorTraversalNode) -> Bool
    ) {
        rows.append(self)
        guard isExpanded(self) else { return }
        for child in children() {
            child.appendExposedRows(to: &rows, isExpanded: isExpanded)
        }
    }
}

/// Projects the currently exposed hierarchy without constructing descendant views.
/// Disclosure preferences remain separate from transient search/navigation expansion.
///
/// Property-backed nodes use the same inclusion predicate as the recursive editor.
/// Other compound-node filtering and presentation special cases still require
/// reconciliation before the flat renderer can replace recursive views.
@MainActor
func sbjEditorFlatRows(
    roots: [SBJEditorTraversalNode],
    presentationModel: SBJEditorPresentationModel,
    temporarilyExpanded: (SBJEditorTraversalNode) -> Bool = { _ in false }
) -> [SBJEditorTraversalNode] {
    var rows: [SBJEditorTraversalNode] = []

    func append(_ node: SBJEditorTraversalNode, criteria: SBJEditSearchCriteria) {
        let navigationMatch = presentationModel.navigationTarget?.contains(node.context.navigationPath) == true
        guard navigationMatch || node.isIncluded(in: criteria) else { return }
        rows.append(node)
        // Existing collection/object editors force open during an active text
        // or changed-only search. They also force open for empty-content-only
        // when the subtree is not known to be empty. Traversal descriptors do
        // not yet track hasContent, so nil matches that conservative behavior.
        let searchExpansion = criteria.forcesExpansion(hasContent: nil)
        let navigationExpansion = presentationModel.navigationTarget?.contains(node.context.navigationPath) == true
        guard presentationModel.resolved(
            node.id,
            mode: node.disclosureMode,
            search: searchExpansion || temporarilyExpanded(node),
            navigation: navigationExpansion
        ) else { return }

        // Once a parent label satisfies the search, its descendants need not
        // match the text independently; other filters continue to apply.
        let childCriteria = criteria.descendingPastMatchedLabel(node.name)
        for child in node.children() {
            append(child, criteria: childCriteria)
        }
    }

    for root in roots {
        append(root, criteria: presentationModel.searchCriteria)
    }
    return rows
}

/// Diagnoses the descriptor output *without* manufacturing views. This is a
/// preflight for the Build 3 rendering migration, not a compilation substitute.
@MainActor
struct SBJEditorProjectionAudit {
    let duplicateIdentifiers: [SBJEditorItemIdentifier]
    let nonRenderableIdentifiers: [SBJEditorItemIdentifier]
    let recursivelyRenderedParents: [SBJEditorItemIdentifier]

    var canUseIndependentFlatRenderer: Bool {
        duplicateIdentifiers.isEmpty && nonRenderableIdentifiers.isEmpty && recursivelyRenderedParents.isEmpty
    }
}

@MainActor
func sbjAuditFlatRows(_ rows: [SBJEditorTraversalNode]) -> SBJEditorProjectionAudit {
    var seen = Set<SBJEditorItemIdentifier>()
    var duplicates: [SBJEditorItemIdentifier] = []
    var missing: [SBJEditorItemIdentifier] = []
    var recursiveParents: [SBJEditorItemIdentifier] = []

    // Projected rows are depth-first. A node's descendants, if any, appear
    // immediately after it, so the next row suffices to detect recursion.
    // This makes the audit O(n) instead of scanning the remaining rows for
    // every recursive parent.
    for (offset, row) in rows.enumerated() {
        if !seen.insert(row.id).inserted { duplicates.append(row.id) }
        if !row.isIndependentlyRenderable { missing.append(row.id) }
        if row.renderingScope == .recursive && row.isIndependentlyRenderable,
           offset + 1 < rows.count {
            let path = row.context.navigationPath
            let nextPath = rows[offset + 1].context.navigationPath
            if nextPath.count > path.count && nextPath.starts(with: path) {
                recursiveParents.append(row.id)
            }
        }
    }
    return SBJEditorProjectionAudit(
        duplicateIdentifiers: duplicates,
        nonRenderableIdentifiers: missing,
        recursivelyRenderedParents: recursiveParents
    )
}

@MainActor
func sbjExposedTraversalRows(
    roots: [SBJEditorTraversalNode],
    isExpanded: (SBJEditorTraversalNode) -> Bool
) -> [SBJEditorTraversalNode] {
    var rows: [SBJEditorTraversalNode] = []
    for root in roots {
        root.appendExposedRows(to: &rows, isExpanded: isExpanded)
    }
    return rows
}
#endif
