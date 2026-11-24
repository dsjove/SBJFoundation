import Testing
@testable import SBJStructure

@SBJStructure
private struct LockedMeasurement {
    @SBJUnitValue(unitMutable: false, defaultUnit: LengthUnit.inch, unit: LengthUnit.inch)
    var length = UnitValue<LengthUnit>(1, unit: .inch)
}

@SBJStructure
private struct PreferredButNotFixedMeasurement {
    @SBJUnitValue(defaultUnit: LengthUnit.inch)
    var length = UnitValue<LengthUnit>(1, unit: .inch)
}

@SBJStructure
private struct MetricMeasurement {
    @SBJUnitValue(unitSystem: .metric)
    var length = UnitValue<LengthUnit>(1, unit: .meter)
}

@Suite struct FixedUnitInvariantTests {
    @Test func explicitRequiredUnitIsDescribed() {
        let constraints = LockedMeasurement.propertyMetadata(for: \.length)?.constraints ?? []
        #expect(constraints.contains(.requiredUnit(SBJDefaultUnit(LengthUnit.inch))))
        #expect(constraints.contains(.unitMutable(false)))
    }

    @Test func preferredUnitDoesNotBecomeAnInvariant() throws {
        var measurement = PreferredButNotFixedMeasurement()
        measurement.length = UnitValue(2, unit: .foot)
        try measurement.invariant(at: .root)
    }

    @Test func measurementSystemIsValidated() throws {
        var value = MetricMeasurement()
        try value.invariant(at: .root)
        value.length = UnitValue(1, unit: .centimeter)
        try value.invariant(at: .root)
        value.length = UnitValue(1, unit: .foot)
        #expect(throws: (any Error).self) {
            try value.invariant(at: .root)
        }
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
