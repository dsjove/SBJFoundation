import Foundation
import Testing
@testable import SBJStructuredEditor
import SBJUnits
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

@SBJEditable
private struct UnitValueEditorFixture: Codable {
    @SBJUnitValue(min: 0)
    var length = UnitValue<LengthUnit>(5, unit: .foot)

    @SBJUnitValue(min: 0)
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
        #expect(UnitValueEditorFixture.sbjEditorFields.map(\.name) == ["Length", "Optional Volume"])
    }
#endif
}

