/// Numeric constraints and a unit editing and measurement-system policy for a measurement.
@attached(peer)
public macro SBJUnitValue(min: Double? = nil, unitMutable: Bool = true, defaultUnit: (any UnitType)? = nil, unit: (any UnitType)? = nil, unitSystem: MeasurementSystem? = nil) = #externalMacro(
    module: "SBJStructureMacros", type: "SBJUnitValueMacro"
)
