import Foundation
import SBJDataDefinition
import Testing
import SBJLocalization
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

@Suite("Search")
struct SearchTests {
    @Test func querifyRetainsOriginalContract() {
        #expect("  hello  ".querify == "hello")
        #expect(" \n ".querify == nil)
    }

    @Test func stringPredicatedIgnoresCaseWhitespaceAndPunctuation() {
        #expect("First Name".predicated(search: "first-name"))
        #expect("SomeIdentifier42".predicated(search: "identifier 42"))
        #expect(!"First Name".predicated(search: "surname"))
    }

    @Test func emptySearchMatchesForFiltering() {
        #expect("Anything".predicated(search: ""))
        #expect("Anything".predicated(search: "---"))
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
    }

    @Test func originalArrayHelpersArePreserved() {
        struct Item: Predicated {
            let text: String
            func predicated(search: String) -> Bool { text.predicated(search: search) }
        }

        let values = [Item(text: "Alpha"), Item(text: "Beta")]
        #expect(values.predicated(search: "beta"))
        #expect(values.filter(search: "alpha").count == 1)
        #expect(values.filter(search: "").count == 2)
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
}
