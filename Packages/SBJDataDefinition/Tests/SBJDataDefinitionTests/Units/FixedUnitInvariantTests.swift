import Testing
@testable import SBJDataDefinition

@SBJStructure
private struct LockedMeasurement {
    @SBJUnitValue(unitMutable: false, defaultUnit: LengthUnit.inch)
    @SBJUnitValuePresentation(.fixedUnit)
    var length = UnitValue<LengthUnit>(1, unit: .inch)
}

@SBJStructure
private struct EditableUnitPresentationFixture {
    @SBJUnitValuePresentation(.editable)
    var length = UnitValue<LengthUnit>(1, unit: .inch)
}

@Suite struct FixedUnitInvariantTests {
    @Test func unitPresentationIsAvailableToConsumers() {
        let metadata = LockedMeasurement.propertyMetadata(for: \.length)
        #expect(metadata?.hints.contains(.unitValuePresentation(SBJUnitValuePresentationValue(mode: .fixedUnit))) == true)
    }

    @Test func editableUnitPresentationIsAvailableToConsumers() {
        let metadata = EditableUnitPresentationFixture.propertyMetadata(for: \.length)
        #expect(metadata?.hints.contains(.unitValuePresentation(SBJUnitValuePresentationValue(mode: .editable))) == true)
    }

    @Test func permittedUnitPasses() throws {
        try LockedMeasurement().invariant(at: .root)
    }

    @Test func changedUnitFails() throws {
        var measurement = LockedMeasurement()
        measurement.length = UnitValue(2, unit: .foot)
        #expect(throws: (any Error).self) {
            try measurement.invariant(at: .root)
        }
    }
}
