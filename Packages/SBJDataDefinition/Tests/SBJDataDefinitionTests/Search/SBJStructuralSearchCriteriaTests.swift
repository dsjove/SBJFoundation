import Testing
@testable import SBJDataDefinition

private struct SearchAggregate {
    var firstName: String
    var count: Int
}

private struct SearchDescribedValue: CustomStringConvertible {
    var description: String { "Display Value" }
}

private struct CustomPredicatedValue: Predicated {
    let visible = "visible"

    func predicated(search query: String) -> Bool {
        query.isEquivalent(to: "special alias") || visible.predicated(search: query)
    }
}

/// Demonstrates the important SearchProtocol use case: the type exposes terms
/// that are not necessarily part of its ordinary display representation.
private struct ExplicitSearchValue: SearchProtocol {
    var name: String
    var alias: String

    var text: String {
        get { "\(name) \(alias) secret-derived-term" }
        set { }
    }
}

private struct ExplicitPredicatedSearchValue: SearchProtocol, Predicated {
    var text = "visible"
    var isEmpty: Bool { text.isEmpty }

    func predicated(search query: String) -> Bool {
        query.isEquivalent(to: "owned rule") || text.predicated(search: query)
    }
}

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

    @Test func editorFallbackUsesValueDescription() {
        #expect(sbjPredicated(SearchDescribedValue(), search: "displayvalue"))
    }

    @Test func editorFallbackUsesSwiftDescriptionForAggregateValues() {
        let value = SearchAggregate(firstName: "Lauren", count: 17)
        #expect(sbjPredicated(value, search: "lauren"))
        #expect(sbjPredicated(value, search: "17"))
    }

    @Test func editorCanMatchLabelOrValue() {
        let value = SearchAggregate(firstName: "Lauren", count: 17)
        #expect(sbjPredicated(label: "Person", value: value, search: "person"))
        #expect(sbjPredicated(label: "Person", value: value, search: "lauren"))
        #expect(!sbjPredicated(label: "Person", value: value, search: "missing"))
    }

    @Test func searchProtocolContributesNonObviousText() {
        let value = ExplicitSearchValue(name: "Visible", alias: "Nickname")
        #expect(sbjPredicated(value, search: "nickname"))
        #expect(sbjPredicated(value, search: "secret derived term"))
        #expect(!sbjPredicated(value, search: "missing"))
    }

    @Test func predicatedOwnsMatchingWhenPresent() {
        let value = CustomPredicatedValue()
        #expect(sbjPredicated(value, search: "special alias"))
        #expect(sbjPredicated(value, search: "visible"))
        #expect(!sbjPredicated(value, search: "missing"))
    }

    @Test func predicatedTakesPriorityOverSearchProtocolText() {
        let value = ExplicitPredicatedSearchValue()
        #expect(sbjPredicated(value, search: "owned rule"))
        #expect(sbjPredicated(value, search: "visible"))
        #expect(!sbjPredicated(value, search: "not owned"))
    }
}
