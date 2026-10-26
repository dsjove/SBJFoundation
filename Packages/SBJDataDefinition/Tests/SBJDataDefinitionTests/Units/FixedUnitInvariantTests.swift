import Testing
@testable import SBJDataDefinition

@SBJStructure
private struct LockedMeasurement {
    @SBJUnitValue(unitMutable: false, defaultUnit: LengthUnit.inch)
    var length = UnitValue<LengthUnit>(1, unit: .inch)
}

@Suite struct FixedUnitInvariantTests {
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
