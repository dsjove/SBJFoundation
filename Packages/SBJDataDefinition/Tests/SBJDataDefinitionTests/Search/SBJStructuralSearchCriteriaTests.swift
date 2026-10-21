import Testing
@testable import SBJDataDefinition

@Suite("Edit search criteria")
struct SBJStructuralSearchCriteriaTests {
    @Test func emptyStateIncludesEveryCriterion() {
        #expect(SBJStructuralSearchCriteria().isEmpty)
        #expect(!SBJStructuralSearchCriteria(searchQuery: "x").isEmpty)
        #expect(!SBJStructuralSearchCriteria(showChangedOnly: true).isEmpty)
        #expect(!SBJStructuralSearchCriteria(showEmptyContentOnly: true).isEmpty)
    }

    @Test func allCriteriaAreAppliedInOnePass() {
        let criteria = SBJStructuralSearchCriteria(
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
        let criteria = SBJStructuralSearchCriteria(
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
        let criteria = SBJStructuralSearchCriteria(
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
