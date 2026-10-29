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

@Test func presentationNotesAndPresentableSequences() {
    #expect(["first", "", "second"].presentationNotes == "first; second")
    #expect([String]().presentationList == "")
    enum Value: String, SBJTextPresentable { case firstChoice, secondChoice }
    #expect([Value.firstChoice, .secondChoice].presentationList == "First Choice, Second Choice")
}

@Test func jargonOverridesAndFormatsTypedValues() {
    let base = Jargon("base", words: ["name": "Base", "other": "Existing"], formatters: [
        "number": JargonFormatter(Int.self) { "Value \($0)" }
    ])
    let local = Jargon("local", overriding: base, words: ["name": "Override"])
    #expect(local.id == "local")
    #expect(local.word("name") == "Override")
    #expect(local.word("other") == "Existing")
    #expect(local.text("unknown") == "unknown")
    #expect(local.text(nil) == nil)
    #expect(local.format("number", value: 3) == "Value 3")
    #expect(local.format("number", value: "wrong") == nil)
    #expect(local.format(nil, value: 3) == nil)
}
