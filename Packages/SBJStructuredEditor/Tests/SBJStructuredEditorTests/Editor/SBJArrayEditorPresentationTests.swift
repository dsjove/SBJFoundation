import SBJDataDefinition
import Testing
@testable import SBJStructuredEditor
import SBJUIVocabulary

@Suite("Array editor presentation")
struct SBJArrayEditorPresentationTests {
    @Test("item numbering uses the underlying array index")
    func itemNumberUsesUnderlyingIndex() {
        #expect(SBJArrayEditorPresentation.itemNumber(for: 0) == 1)
        #expect(SBJArrayEditorPresentation.itemNumber(for: 3) == 4)
        #expect(SBJArrayEditorPresentation.itemNumber(for: 8) == 9)
    }

    @Test("reordering is disabled whenever the displayed array is filtered")
    func filteredSubsetDetection() {
        #expect(!SBJArrayEditorPresentation.isDisplayingFilteredSubset(
            criteria: SBJStructuralSearchCriteria()
        ))

        #expect(SBJArrayEditorPresentation.isDisplayingFilteredSubset(
            criteria: SBJStructuralSearchCriteria(searchQuery: "needle")
        ))

        #expect(SBJArrayEditorPresentation.isDisplayingFilteredSubset(
            criteria: SBJStructuralSearchCriteria(showChangedOnly: true)
        ))

        #expect(SBJArrayEditorPresentation.isDisplayingFilteredSubset(
            criteria: SBJStructuralSearchCriteria(showEmptyContentOnly: true)
        ))
    }
    @Test("collection element removal remains independently actionable")
    @MainActor
    func collectionElementRemoval() {
        var wasRemoved = false
        let actions = SBJEditorItemActions(remove: { wasRemoved = true }, moveUp: nil, moveDown: nil)
        // Construct the shared information-gutter control without requiring
        // element-specific compile-time property metadata.
        _ = actions.infoLaneView
        _ = actions.trailingView
        actions.remove?()
        #expect(wasRemoved)
    }

}

private struct DuplicateIdentifierFixture {
    var name: String
}

extension SBJArrayEditorPresentationTests {
    @Test("duplicate collection identifiers receive distinct slot identities")
    func duplicatedIdentifiersUsePositionalIdentity() {
        let items = [
            DuplicateIdentifierFixture(name: "Strength"),
            DuplicateIdentifierFixture(name: "Strength")
        ]
        let nodes = SBJCollectionTraversal.array(items, itemIdentifierKey: "name")
        #expect(nodes.map(\.identifier) == ["item:slot:0", "item:slot:1"])
        #expect(nodes.map(\.index) == [0, 1])
    }
}
