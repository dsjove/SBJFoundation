#if !os(tvOS) && !os(watchOS)
import SwiftUI
import Testing
@testable import SBJFoundation

@MainActor
@Suite("Changed filter subtree projection")
struct SBJChangedFilterProjectionTests {
    final class Fixture {
        var mark = "Proficient"
    }

    private func tree(_ fixture: Fixture) -> SBJEditorTraversalNode {
        func make(_ names: ArraySlice<String>, parent: SBJEditorItemIdentifier) -> SBJEditorTraversalNode {
            let name = names.first!
            let id = parent.appending(name)
            let isLeaf = names.count == 1
            return SBJEditorTraversalNode(
                context: SBJEditTraversalContext(treeLevel: 0, itemIdentifier: id),
                name: name,
                isDisclosure: !isLeaf,
                isIncluded: { criteria in
                    criteria.includes(
                        isChanged: isLeaf && fixture.mark != "Proficient",
                        containsEmptyContent: false,
                        matchesSearch: { $0.isEmpty || name.localizedCaseInsensitiveContains($0) }
                    )
                },
                children: { _ in
                    isLeaf ? [] : [make(names.dropFirst(), parent: id)]
                }
            )
        }
        return make(["Capabilities", "Skills", "Arcana", "Mark"][...], parent: .root)
    }

    @Test("Changed retains unmatched ancestors of changed descendants")
    func changedDescendant() {
        let fixture = Fixture()
        let model = SBJEditorPresentationModel()
        model.searchCriteria.showChangedOnly = true
        fixture.mark = "Normal"
        let rows = sbjEditorRows(roots: [tree(fixture)], presentationModel: model)
        #expect(rows.map(\.name) == ["Capabilities", "Skills", "Arcana", "Mark"])
        #expect(rows.map(\.depth) == [0, 1, 2, 3])
        #expect(rows[3].endDividerLevels == [3, 2, 1])
    }

    @Test("Filter toggling and restoring the value do not retain stale matches")
    func filterToggleAndRestore() {
        let fixture = Fixture()
        let model = SBJEditorPresentationModel()
        let root = tree(fixture)
        model.searchCriteria.showChangedOnly = true
        #expect(sbjEditorRows(roots: [root], presentationModel: model).isEmpty)
        fixture.mark = "Normal"
        #expect(sbjEditorRows(roots: [root], presentationModel: model).map(\.name).last == "Mark")
        fixture.mark = "Proficient"
        #expect(sbjEditorRows(roots: [root], presentationModel: model).isEmpty)
        model.searchCriteria.showChangedOnly = false
        #expect(sbjEditorRows(roots: [root], presentationModel: model).map(\.name) == ["Capabilities"])
    }
}
#endif
