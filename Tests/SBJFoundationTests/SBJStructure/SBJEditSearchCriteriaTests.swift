import SBJUIVocabulary
import Testing
import SBJDataDefinition
@testable import SBJFoundation

@Suite("Edit search criteria")
struct SBJEditSearchCriteriaTests {
    @Test func emptyStateIncludesEveryCriterion() {
        #expect(SBJEditSearchCriteria().isEmpty)
        #expect(!SBJEditSearchCriteria(searchQuery: "x").isEmpty)
        #expect(!SBJEditSearchCriteria(showChangedOnly: true).isEmpty)
        #expect(!SBJEditSearchCriteria(showEmptyContentOnly: true).isEmpty)
    }

    @Test func allCriteriaAreAppliedInOnePass() {
        let criteria = SBJEditSearchCriteria(
            searchQuery: "needle",
            showChangedOnly: true,
            showEmptyContentOnly: true
        )

        #expect(criteria.includes(
            isChanged: true,
            containsEmptyContent: true,
            matchesSearch: { $0 == "needle" }
        ))
        #expect(!criteria.includes(
            isChanged: false,
            containsEmptyContent: true,
            matchesSearch: { _ in true }
        ))
        #expect(!criteria.includes(
            isChanged: true,
            containsEmptyContent: false,
            matchesSearch: { _ in true }
        ))
        #expect(!criteria.includes(
            isChanged: true,
            containsEmptyContent: true,
            matchesSearch: { _ in false }
        ))
    }

    @Test func matchedAncestorClearsOnlyTextQuery() {
        let criteria = SBJEditSearchCriteria(
            searchQuery: "Inventory",
            showChangedOnly: true,
            showEmptyContentOnly: true
        )
        let child = criteria.descendingPastMatchedLabel("Inventory")

        #expect(child.searchQuery.isEmpty)
        #expect(child.showChangedOnly)
        #expect(child.showEmptyContentOnly)
    }

    @Test func descendantQueryClearsWhenAnyCompoundLabelMatches() {
        let criteria = SBJEditSearchCriteria(
            searchQuery: "second",
            showChangedOnly: true,
            showEmptyContentOnly: true
        )

        let descended = criteria.descendingPastMatchedLabels("First", "Second Label")
        #expect(descended.searchQuery.isEmpty)
        #expect(descended.showChangedOnly)
        #expect(descended.showEmptyContentOnly)

        let unmatched = criteria.descendingPastMatchedLabels("First", "Third")
        #expect(unmatched == criteria)
    }
}
