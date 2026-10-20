import SBJUnits
import SBJUIVocabulary
import Foundation
import SBJDataDefinition
import Testing
@testable import SBJFoundation

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

    @Test func legacyQuantityKindKeyStillDecodes() throws {
        let data = Data(#"{"value":5,"kind":"foot"}"#.utf8)
        let decoded = try JSONDecoder().decode(UnitValue<LengthUnit>.self, from: data)
        #expect(decoded == UnitValue(5, unit: .foot))
    }

    @Test func encodedShapeUsesNewUnitKey() throws {
        let data = try JSONEncoder().encode(UnitValue<MassUnit>(1, unit: .pound))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["unit"] as? String == "pound")
        #expect(object["kind"] == nil)
    }

    @Test func pointConversionMatchesPDFDefinition() {
        let inch = UnitValue<LengthUnit>(72, unit: .point).converted(to: .inch)
        #expect(abs(inch.value - 1) < 0.000_001)
    }

#if !os(watch)
    @Test func unitValueIsAStockTypedEditorValue() {
        func requireTypedEditorValue<T: SBJTypedEditorValue>(_: T.Type) {}
        requireTypedEditorValue(UnitValue<LengthUnit>.self)
        requireTypedEditorValue(UnitValue<MassUnit>.self)
        requireTypedEditorValue(UnitValue<VolumeUnit>.self)
        requireTypedEditorValue(UnitValue<DurationUnit>.self)
    }
#endif
}

@SBJEditable
private struct UnitValueEditorFixture: Codable {
    @SBJUnitValue(min: 0)
    var length = UnitValue<LengthUnit>(5, unit: .foot)

    @SBJUnitValue(min: 0)
    var optionalVolume: UnitValue<VolumeUnit>? = .init(1, unit: .cup)
}

extension UnitValueTests {
    @Test func unitValueMinimumAnnotationParticipatesInGeneratedInvariant() throws {
        try UnitValueEditorFixture().invariant(at: \UnitValueEditorFixture.self)
        #expect(throws: SBJValidationError.self) {
            try UnitValueEditorFixture(length: .init(-1, unit: .foot))
                .invariant(at: \UnitValueEditorFixture.self)
        }
    }

#if !os(watch)
    @MainActor
    @Test func structuredEditorRecognizesUnitValuesWithoutCustomRegistry() {
        let issues = SBJEditorDiagnostics.issues(for: UnitValueEditorFixture())
        #expect(issues.isEmpty)
        #expect(UnitValueEditorFixture.sbjEditorFields.map(\.name) == ["Length", "Optional Volume"])
    }
#endif
}

extension UnitValueTests {
    @Test func editingStepsArePolicyRatherThanUnitSemantics() {
        let policy = UnitEditingPolicy<VolumeUnit>(
            defaultStep: 1,
            overrides: [.cup: 0.25]
        )
        let value = UnitValue<VolumeUnit>(1, unit: .cup)
        #expect(policy.stepped(value, increasing: true).value == 1.25)
        #expect(policy.stepAmount(for: .liter) == 1)
    }
}

extension UnitValueTests {
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

    @MainActor
    @Test func conversionViewsRetainSharedPublicSurface() {
        let model = UnitConversionModel(
            source: UnitValue<VolumeUnit>(1, unit: .cup),
            destinationUnit: .liter
        )

        _ = UnitConversionView(model: model)
        _ = ConversionView()
    }
}
