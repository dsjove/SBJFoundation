import Testing
@testable import SBJDataDefinition

@Suite("Search text normalization")
struct SearchTextUtilitiesTests {
    @Test func whitespaceNormalization() {
        #expect("  Hello \n".trimmed == "Hello")
        #expect(" \n ".querify == nil)
    }
}
