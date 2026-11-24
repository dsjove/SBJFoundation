import Testing
@testable import SBJLocalization

@Suite("String equivalence")
struct StringEquivalenceTests {
    @Test func caseInsensitiveComparison() {
        #expect("  Hello ".isEquivalent(to: "hello"))
    }
}
