import Foundation
import Testing
import SBJDataDefinition

@Suite("SBJUnits model")
struct SBJUnitsTests {
    @Test func conversionRetainsSourceAndConvertsQuantity() {
        let original = UnitValue<LengthUnit>(12, unit: .inch)
        let converted = original.converted(to: .foot)
        #expect(abs(converted.value - 1) < 0.000_001)
        #expect(converted.unit == .foot)
        #expect(original.unit == .inch)
    }

    @Test func codablePreservesSelectedUnit() throws {
        let original = UnitValue<VolumeUnit>(2.5, unit: .tablespoon)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UnitValue<VolumeUnit>.self, from: encoded)
        #expect(decoded == original)
    }
    @Test func nomenclatureUsesUncamelCasedRawValues() {
        #expect(VolumeUnit.fluidOunce.presentedValue == "Fluid Ounce")
        #expect(VolumeUnit.fluidOunce.abbreviation == "fl oz")
        #expect(MeasurementSystem.imperial.presentedValue == "Imperial")
    }
}
