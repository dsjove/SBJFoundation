import Foundation
import Testing
@testable import SBJUIVocabulary

struct CodableFontTests {
    @Test func uncachedFontConvenienceSupportsScale() {
        let specification = CodableFont(nil, ofSize: 10)

        #expect(specification.font.pointSize == 10)
        #expect(specification.font(scale: 1.25).pointSize == 12.5)
    }

    @Test func cacheReusesFontsForIdenticalKeys() {
        let cache = CodableFontCache()
        let specification = CodableFont(nil, ofSize: 10, weight: .bold)

        let first = cache.font(for: specification, scale: 1.2)
        let second = cache.font(for: specification, scale: 1.2)

        #expect(first === second)
        #expect(first.pointSize == 12)
    }
}
