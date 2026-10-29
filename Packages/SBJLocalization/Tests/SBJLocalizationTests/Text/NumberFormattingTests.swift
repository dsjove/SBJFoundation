import Testing
@testable import SBJLocalization

@Suite("SBJ number formatting")
struct NumberFormattingTests {
    @Test func decimalStyleUsesSignificantDigits() {
        #expect(SBJNumberFormatStyle.decimal(significantDigits: 3).format(12.345) == "12.3")
        #expect(SBJNumberFormatStyle.decimal(significantDigits: 1).format(5) == "5")
    }

    @Test func fractionStyleSupportsCommonFractionsAndWholeValues() {
        let style = SBJNumberFormatStyle.fraction(fallbackSignificantDigits: 3)
        #expect(style.format(0.5) == "1/2")
        #expect(style.format(1.25) == "1 1/4")
        #expect(style.format(-0.5) == "-1/2")
        #expect(style.format(2) == "2")
    }
}
