import SBJUIVocabulary
import Testing
import SBJDataDefinition
@testable import SBJFoundation

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
            criteria: SBJEditSearchCriteria()
        ))

        #expect(SBJArrayEditorPresentation.isDisplayingFilteredSubset(
            criteria: SBJEditSearchCriteria(searchQuery: "needle")
        ))

        #expect(SBJArrayEditorPresentation.isDisplayingFilteredSubset(
            criteria: SBJEditSearchCriteria(showChangedOnly: true)
        ))

        #expect(SBJArrayEditorPresentation.isDisplayingFilteredSubset(
            criteria: SBJEditSearchCriteria(showEmptyContentOnly: true)
        ))
    }
}
