import Foundation
import Testing
@testable import SBJStructuredEditor
import SBJDataDefinition

@Suite("Unit value editor integration")
struct UnitValueEditorTests {
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

@SBJStructure
private struct UnitValueEditorFixture: Codable {
    @SBJUnitValue(min: 0, defaultUnit: LengthUnit.foot)
    var length = UnitValue<LengthUnit>(5, unit: .foot)

    @SBJUnitValue(min: 0, defaultUnit: VolumeUnit.cup)
    var optionalVolume: UnitValue<VolumeUnit>? = .init(1, unit: .cup)
}

extension UnitValueEditorTests {
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
        #expect(SBJStructuralFieldProjection.fields(of: UnitValueEditorFixture.self).map(\.name) == ["Length", "Optional Volume"])
    }
#endif
}

