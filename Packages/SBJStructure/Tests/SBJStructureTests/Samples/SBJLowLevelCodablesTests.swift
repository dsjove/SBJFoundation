import Foundation
import Testing
import SBJLocalization
@testable import SBJStructure

struct SBJLowLevelCodablesTests {
    @Test func unitsRetainConversionAndCodableRoundtrip() throws {
        let value = UnitValue<LengthUnit>(12, unit: .inch)
        #expect(abs(value.converted(to: .foot).value - 1) < 0.000_000_1)
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(UnitValue<LengthUnit>.self, from: encoded)
        #expect(decoded == value)
        #expect(UnitValue<LengthUnit>.sbjProperties.map(\.sourceName) == ["value", "unit"])
    }

    @Test func fontAndColorKeepDefinitionCapabilities() throws {
        let font = CodableFont(nil, ofSize: 14)
        #expect(CodableFont.sbjProperties.map(\.sourceName) == ["family", "size", "weight", "italic", "width"])
        #expect(font.sbjStructuralEquals(CodableFont(nil, ofSize: 14)))
        let color = CodableColor(0.2, 0.3, 0.4, 0.5)
        let roundtripped = try JSONDecoder().decode(CodableColor.self, from: JSONEncoder().encode(color))
        #expect(roundtripped == color)
    }
}
