/// Numeric constraints and a unit-change policy for a measurement.
@attached(peer)
public macro SBJUnitValue(min: Double? = nil, immutableUnit: Bool = false, defaultUnit: (any UnitType)? = nil) = #externalMacro(
    module: "SBJDataDefinitionMacros", type: "SBJUnitValueMacro"
)
