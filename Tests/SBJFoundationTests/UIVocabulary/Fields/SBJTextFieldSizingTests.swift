import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import Testing
import SBJDataDefinition
@testable import SBJFoundation

struct SBJTextFieldSizingTests {
    @Test func unconstrainedTextDoesNotImposeCompactWidth() {
        #expect(SBJTextFieldSizing.singleLine(maximumLength: nil) == nil)
        #expect(SBJTextFieldSizing.singleLine(maximumLength: 97) == nil)
    }

    @Test func constrainedTextUsesIncreasingSizeTiers() throws {
        let short = try #require(SBJTextFieldSizing.singleLine(maximumLength: 12))
        let medium = try #require(SBJTextFieldSizing.singleLine(maximumLength: 24))
        let long = try #require(SBJTextFieldSizing.singleLine(maximumLength: 48))
        let longest = try #require(SBJTextFieldSizing.singleLine(maximumLength: 96))
        #expect(short.ideal < medium.ideal)
        #expect(medium.ideal < long.ideal)
        #expect(long.ideal < longest.ideal)
    }
}
#endif
