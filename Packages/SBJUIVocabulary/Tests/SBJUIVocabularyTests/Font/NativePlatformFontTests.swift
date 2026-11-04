import Foundation
import Testing
@testable import SBJUIVocabulary

#if canImport(AppKit)
import AppKit

struct NativePlatformFontTests {
    @Test func macOSRealizesAndCachesNativeFonts() {
        let font = CodableFont(nil, ofSize: 13, weight: .semibold)
        let cache = CodableFontCache()
        let first: NSFont = cache.font(for: font)
        let second = cache.font(for: font)
        #expect(first === second)
        #expect(first.pointSize == 13)
        #expect(font.nsFont().pointSize == 13)
    }
}
#endif
