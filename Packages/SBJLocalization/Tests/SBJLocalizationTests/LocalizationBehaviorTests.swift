import Testing
@testable import SBJLocalization

@Test func presentationListsOmitEmptyValues() {
    #expect(["alpha", "", "beta"].bulleted() == "alpha • beta")
    #expect(["alpha", "", "beta"].presentationList == "alpha, beta")
}

@Test func optionalBulletsRetainExistingPrefixSemantics() {
    let values: [String?] = ["alpha", nil, "beta"]
    #expect(values.bulleted(prefix: "*") == "alpha • beta")
}
