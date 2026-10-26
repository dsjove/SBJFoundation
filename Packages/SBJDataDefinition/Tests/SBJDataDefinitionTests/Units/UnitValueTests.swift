import Foundation
import Testing
@testable import SBJDataDefinition

@Suite("Unit values")
struct UnitValueTests {
    @Test func conversionPreservesPhysicalQuantityAndChangesUnit() {
        let inches = UnitValue<LengthUnit>(12, unit: .inch)
        let feet = inches.converted(to: .foot)

        #expect(abs(feet.value - 1) < 0.000_001)
        #expect(feet.unit == .foot)
        #expect(inches.value == 12)
        #expect(inches.unit == .inch)
    }

    @Test func codableRoundTripPreservesAmountAndUnit() throws {
        let original = UnitValue<VolumeUnit>(2.5, unit: .tablespoon)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UnitValue<VolumeUnit>.self, from: data)
        #expect(decoded == original)
    }

    @Test func encodedShapeUsesNewUnitKey() throws {
        let data = try JSONEncoder().encode(UnitValue<MassUnit>(1, unit: .pound))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["unit"] as? String == "pound")
        #expect(object["kind"] == nil)
    }

    @Test func structureMacroDescribesQuantityAndImmutableUnit() throws {
        typealias Value = UnitValue<LengthUnit>
        #expect(Value.sbjProperties.map(\.sourceName) == ["value", "unit"])
        #expect(Value.sbjMutableProperties.map(\.structuralMetadata?.sourceName) == ["value"])
        #expect(Value.sbjDefaultValue()?.unit == LengthUnit.allCases.first)
        let valid = Value(1, unit: .inch)
        #expect(valid.sbjStructuralEquals(Value(1, unit: .inch)))
        #expect(!valid.sbjStructuralEquals(Value(2, unit: .inch)))
    }

    @Test func structureMacroDescribesEditingPolicy() {
        typealias Policy = UnitEditingPolicy<LengthUnit>
        #expect(Policy.sbjProperties.map(\.sourceName) == ["defaultStep", "overrides"])
        #expect(Policy.sbjMutableProperties.count == 2)
        #expect(Policy.sbjDefaultValue()?.defaultStep == 1)
    }

    @Test func unitEnumsExposeMacroCaseNames() {
        #expect(LengthUnit.sbjCaseNames.contains("millimeter"))
        #expect(LengthUnit.millimeter.sbjCaseName == "millimeter")
        #expect(MeasurementSystem.sbjCaseNames == ["metric", "imperial", "universal"])
    }

    @Test func pointConversionMatchesPDFDefinition() {
        let inch = UnitValue<LengthUnit>(72, unit: .point).converted(to: .inch)
        #expect(abs(inch.value - 1) < 0.000_001)
    }

}

@Suite("Unit conversion and editing policy")
struct UnitConversionAndPolicyTests {
    @Test func editingStepsArePolicyRatherThanUnitSemantics() {
        let policy = UnitEditingPolicy<VolumeUnit>(
            defaultStep: 1,
            overrides: [.cup: 0.25]
        )
        let value = UnitValue<VolumeUnit>(1, unit: .cup)
        #expect(policy.stepped(value, increasing: true).value == 1.25)
        #expect(policy.stepAmount(for: .liter) == 1)
    }
    @MainActor
    @Test func conversionModelOwnsSharedWorkflowSemantics() {
        let model = UnitConversionModel(
            source: UnitValue<LengthUnit>(12, unit: .inch),
            destinationUnit: .foot
        )

        #expect(abs(model.result.value - 1) < 0.000_001)
        #expect(model.result.unit == .foot)

        model.swap()
        #expect(abs(model.source.value - 1) < 0.000_001)
        #expect(model.source.unit == .foot)
        #expect(model.destinationUnit == .inch)

        model.reset(to: 3)
        #expect(model.source.value == 3)
    }

}
