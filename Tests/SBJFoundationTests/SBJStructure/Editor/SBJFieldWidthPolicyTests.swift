import Testing
import SBJDataDefinition
@testable import SBJFoundation

@Suite("Editor field width policy")
struct SBJFieldWidthPolicyTests {
    @Test func unconstrainedSingleLineTextFillsAvailableWidth() {
        #expect(SBJAdaptiveFieldControlWidth.singleLineText(maximumLength: nil) == .fillAvailable())
    }

    @Test func constrainedSingleLineTextRemainsIntrinsic() {
        #expect(SBJAdaptiveFieldControlWidth.singleLineText(maximumLength: 80) == .intrinsic)
    }
}
