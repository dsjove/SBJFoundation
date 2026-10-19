/// Numeric constraints and a unit-change policy for a measurement.
@attached(peer)
public macro SBJUnitValue(min: Double? = nil, immutableUnit: Bool = false) = #externalMacro(
    module: "SBJDataDefinitionMacros", type: "SBJUnitValueMacro"
)
