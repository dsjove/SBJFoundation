import SwiftUI
import Testing
@testable import SBJStructuredEditor
import SBJUIVocabulary
import SBJUnits
#if !os(tvOS) && !os(watchOS)

@MainActor
@Suite("Projected disclosure boundaries")
struct SBJProjectedDisclosureDividerTests {
    private func node(_ name: String, depth: Int, isDisclosure: Bool = false,
                      children: @escaping (SBJEditTraversalContext) -> [SBJEditorTraversalNode] = { _ in [] }) -> SBJEditorTraversalNode {
        SBJEditorTraversalNode(
            context: SBJEditTraversalContext(
                treeLevel: depth,
                itemIdentifier: .root.appending(name)
            ),
            name: name,
            isDisclosure: isDisclosure,
            children: children
        )
    }

    @Test("projection normalizes stale child depths and closes deepest first")
    func correctedChildDepth() {
        let model = SBJEditorPresentationModel()
        model.open(.root.appending("outer"))
        model.open(.root.appending("middle"))
        model.open(.root.appending("inner"))
        // Simulate three independently constructed child descriptors that all
        // accidentally retained the root depth. Their position in the tree,
        // rather than those stale integers, determines the rendered levels.
        let inner = node("inner", depth: 0, isDisclosure: true)
        let middle = node("middle", depth: 0, isDisclosure: true) { _ in [inner] }
        let outer = node("outer", depth: 0, isDisclosure: true) { _ in [middle] }
        let rows = sbjEditorRows(roots: [outer], presentationModel: model)
        #expect(rows.map(\.depth) == [0, 1, 2])
        #expect(rows[2].endDividerLevels == [3, 2, 1])
        #expect(rows[2].endDividerLevels[0] == rows[2].context.treeLevel + 1)
    }

    @Test("child factory receives the projected parent context at every level")
    func projectedContextReachesChildren() {
        let model = SBJEditorPresentationModel()
        let outerID = SBJEditorItemIdentifier.root.appending("outer")
        let middleID = outerID.appending("middle")
        let innerID = middleID.appending("inner")
        model.open(outerID)
        model.open(middleID)
        model.open(innerID)
        var factoryDepths: [Int] = []

        func make(_ name: String, id: SBJEditorItemIdentifier, remaining: Int) -> SBJEditorTraversalNode {
            SBJEditorTraversalNode(
                context: SBJEditTraversalContext(treeLevel: 0, itemIdentifier: id),
                name: name,
                isDisclosure: true,
                children: { parentContext in
                    factoryDepths.append(parentContext.treeLevel)
                    guard remaining > 0 else { return [] }
                    let childID = id.appending(remaining == 2 ? "middle" : "inner")
                    return [make(remaining == 2 ? "middle" : "inner", id: childID, remaining: remaining - 1)]
                }
            )
        }

        let rows = sbjEditorRows(
            roots: [make("outer", id: outerID, remaining: 2)],
            presentationModel: model
        )
        #expect(rows.map(\.depth) == [0, 1, 2])
        #expect(factoryDepths == [0, 1, 2])
        #expect(rows[2].endDividerLevels == [3, 2, 1])
    }

    @Test("collapsed groups do not close with dividers")
    func collapsed() {
        let model = SBJEditorPresentationModel()
        let parent = node("parent", depth: 0, isDisclosure: true) { _ in
            [self.node("child", depth: 1)]
        }
        let rows = sbjEditorRows(roots: [parent], presentationModel: model)
        #expect(rows.count == 1)
        #expect(rows[0].endDividerLevels.isEmpty)
    }

    @Test("expanded nested groups close from deepest to shallowest")
    func nested() {
        let model = SBJEditorPresentationModel()
        model.open(.root.appending("outer"))
        model.open(.root.appending("inner"))
        let inner = node("inner", depth: 1, isDisclosure: true) { _ in
            [self.node("last", depth: 2)]
        }
        let outer = node("outer", depth: 0, isDisclosure: true) { _ in [inner] }
        let rows = sbjEditorRows(roots: [outer], presentationModel: model)
        #expect(rows.count == 3)
        #expect(rows[0].endDividerLevels.isEmpty)
        #expect(rows[1].endDividerLevels.isEmpty)
        #expect(rows[2].endDividerLevels == [2, 1])
    }

    @Test("open empty disclosure still gets a closing divider")
    func empty() {
        let model = SBJEditorPresentationModel()
        model.open(.root.appending("empty"))
        let rows = sbjEditorRows(
            roots: [node("empty", depth: 0, isDisclosure: true)],
            presentationModel: model
        )
        #expect(rows.count == 1)
        #expect(rows[0].endDividerLevels == [1])
        #expect(rows[0].endDividerLevels[0] == rows[0].context.treeLevel + 1)
    }

    @Test("projected search state is stored in the row context")
    func projectedSearchContext() {
        let model = SBJEditorPresentationModel()
        let root = node("field", depth: 0)
        let rows = sbjEditorRows(roots: [root], presentationModel: model)
        #expect(rows.count == 1)
        #expect(rows[0].context.branch.searchCriteria == model.searchCriteria)
    }

    @Test("node disclosure mode has one context-backed source")
    func disclosureModeContext() {
        let root = SBJEditorTraversalNode(
            context: SBJEditTraversalContext(treeLevel: 2),
            name: "entry",
            disclosureMode: .autoOpen,
            isDisclosure: true
        )
        #expect(root.disclosureMode == root.context.branch.disclosureMode)
        #expect(root.context.treeLevel == 2)
    }

    @Test("flat rendering uses projected context, never factory-captured context")
    func projectedContextReachesRow() {
        let model = SBJEditorPresentationModel()
        let original = SBJEditTraversalContext(
            treeLevel: 3,
            itemIdentifier: .root.appending("bound"),
            navigationPath: ["bound"]
        )
        var actualContext: SBJEditTraversalContext?
        let bound = SBJEditorTraversalNode(
            context: original,
            name: "bound",
            render: { renderedContext in
                actualContext = renderedContext
                return AnyView(EmptyView())
            },
        )
        let rows = sbjEditorRows(roots: [bound], presentationModel: model)
        #expect(rows.count == 1)
        _ = rows[0].renderedRow()
        #expect(actualContext?.treeLevel == rows[0].context.treeLevel)
        #expect(actualContext?.itemIdentifier == rows[0].context.itemIdentifier)
        #expect(actualContext?.branch.searchCriteria == rows[0].context.branch.searchCriteria)
    }

    @Test("a rendered nested disclosure and its divider use the same traversal tree")
    func renderedContextMatchesGroupEnds() {
        let model = SBJEditorPresentationModel()
        model.open(.root.appending("group"))
        let context = SBJEditTraversalContext(
            treeLevel: 3,
            itemIdentifier: .root.appending("group")
        )
        var rendered: SBJEditTraversalContext?
        let group = SBJEditorTraversalNode(
            context: context,
            name: "group",
            isDisclosure: true,
            render: { received in
                rendered = received
                return AnyView(EmptyView())
            },
        )
        let rows = sbjEditorRows(roots: [group], presentationModel: model)
        #expect(rows.count == 1)
        _ = rows[0].renderedRow()
        #expect(rendered?.treeLevel == 3)
        #expect(rows[0].endDividerLevels.count == 1)
        #expect(rows[0].endDividerLevels[0] == rendered!.descended().treeLevel)
    }

    @Test("a leaf cannot gain a divider from forced expansion")
    func leaf() {
        let model = SBJEditorPresentationModel()
        model.open(.root.appending("leaf"))
        let rows = sbjEditorRows(roots: [node("leaf", depth: 0)], presentationModel: model)
        #expect(rows.count == 1)
        #expect(rows[0].endDividerLevels.isEmpty)
    }
}

@Suite("Indentation geometry")
struct SBJEditorIndentationGeometryTests {
    @Test("divider begins at the center of the last indentation slot")
    func dividerCenters() {
        let formatting = SBJEditorFormattingOptions(indentationWidth: 8)
        let first = formatting.indentBulletCenter(forLevel: 1)
        #expect(first == formatting.statusLaneWidth + formatting.statusToContentSpacing + 4)
        #expect(formatting.indentBulletCenter(forLevel: 2) == first + 8)
        #expect(formatting.indentBulletCenter(forLevel: 3) == first + 16)
    }
}
#endif
