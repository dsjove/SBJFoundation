import SBJUIVocabulary
import Testing
import SBJDataDefinition
import UIKit
@testable import SBJFoundation

struct CodableFontTests {
    @Test func systemFontSortsBeforeNamedFontsWithoutCrashing() {
        let system = CodableFont(nil, ofSize: 12)
        let named = CodableFont("Helvetica", ofSize: 12)

        #expect(system < named)
        #expect(!(named < system))
    }

    @Test func comparableUsesAllFontTraits() {
        let regular = CodableFont("Helvetica", ofSize: 12)
        let bold = CodableFont("Helvetica", ofSize: 12, weight: .bold)
        let italic = CodableFont("Helvetica", ofSize: 12, weight: .bold, italic: true)

        #expect(regular < bold)
        #expect(bold < italic)
        #expect(!(italic < italic))
    }

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
    @Test func fontNameNormalizesAndIsLiteralInitializable() {
        let family: FontFamily = "  Helvetica  "
        #expect(family.name == "Helvetica")
        let font = CodableFont("Helvetica", ofSize: 12)
        #expect(font.family == family)
    }

    @Test func fontNameUsesSynthesizedCodable() throws {
        let name: FontFamily = "Helvetica"
        let encoded = try JSONEncoder().encode(name)
        let decoded = try JSONDecoder().decode(FontFamily.self, from: encoded)
        #expect(decoded == name)
        #expect(decoded.name == "Helvetica")
    }

}
