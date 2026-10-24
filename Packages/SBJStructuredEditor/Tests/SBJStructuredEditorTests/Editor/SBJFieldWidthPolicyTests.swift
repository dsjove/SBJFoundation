import Testing
@testable import SBJStructuredEditor
import SBJUIVocabulary

@Suite("Editor field width policy")
struct SBJFieldWidthPolicyTests {
    @Test func unconstrainedSingleLineTextFillsAvailableWidth() {
        #expect(SBJAdaptiveFieldControlWidth.singleLineText(maximumLength: nil) == .fillAvailable())
    }

    @Test func constrainedSingleLineTextRemainsIntrinsic() {
        #expect(SBJAdaptiveFieldControlWidth.singleLineText(maximumLength: 80) == .intrinsic)
    }
}
