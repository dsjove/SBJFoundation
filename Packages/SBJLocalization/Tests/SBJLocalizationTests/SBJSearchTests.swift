import Foundation
import Testing
@testable import SBJLocalization

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
    
    @Test func whitespaceNormalization() {
        #expect("  Hello \n".trimmed == "Hello")
        #expect(" \n ".querify == nil)
    }
}
