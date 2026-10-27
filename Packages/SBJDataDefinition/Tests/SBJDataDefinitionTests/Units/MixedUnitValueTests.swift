import Foundation
import Testing
@testable import SBJDataDefinition

private enum SampleAbility: String, Codable, CaseIterable, Hashable, SBJCollectionElementCreatable {
    case strength, dexterity, constitution
}

struct MixedUnitValueTests {
    @Test func convertsFeetAndInchesToInches() {
        let height = MixedUnitValue(
            major: UnitValue(5, unit: LengthUnit.foot),
            minor: UnitValue(9, unit: LengthUnit.inch)
        )
        #expect(abs(height.converted(to: .inch).value - 69) < 0.00001)
    }

    @Test func retainsSeparateUnitsThroughCoding() throws {
        let height = MixedUnitValue(
            major: UnitValue(5, unit: LengthUnit.foot),
            minor: UnitValue(9, unit: LengthUnit.inch)
        )
        let decoded = try JSONDecoder().decode(
            MixedUnitValue<LengthUnit>.self,
            from: JSONEncoder().encode(height)
        )
        #expect(decoded == height)
    }

    @Test func automaticallyChoosesUnusedEnumCase() {
        #expect(SampleAbility.sbjCreateValue(existing: [.strength, .constitution]) == .dexterity)
        #expect(SampleAbility.sbjCreateValue(existing: [.strength, .dexterity, .constitution]) == nil)
    }

    @Test func choosesFirstUnoccupiedKey() {
        let next = SBJUniqueCollectionCandidate.next(
            from: ["Strength", "Dexterity", "Constitution"],
            existing: ["Strength", "Constitution"],
            by: { $0 }
        )
        #expect(next == "Dexterity")
        let exhausted = SBJUniqueCollectionCandidate.next(
            from: ["Strength"], existing: ["Strength"], by: { $0 }
        )
        #expect(exhausted == nil)
    }
}
