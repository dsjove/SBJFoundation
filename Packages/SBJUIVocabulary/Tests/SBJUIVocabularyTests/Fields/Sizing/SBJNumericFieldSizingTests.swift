import Foundation
import Testing
@testable import SBJUIVocabulary

struct SBJNumericFieldSizingTests {
    @Test func constrainedNumericSizingStaysOrderedAcrossLocales() {
        for localeID in ["en_US", "de_DE", "fr_FR", "ar_SA"] {
            let sizing = SBJNumericFieldSizing.integer(range: -12_345...98_765, locale: Locale(identifier: localeID))
            #expect(sizing.minimum <= sizing.ideal)
            #expect(sizing.ideal <= sizing.maximum)
            #expect(sizing.maximum <= 176)
        }
    }
}
