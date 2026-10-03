/// Adds numeric constraints to a `UnitValue` property declared by `@SBJStructure`.
/// The unit remains part of the value; constraints apply to its numeric amount.
@attached(peer)
public macro SBJUnitValue(min: Double) = #externalMacro(
    module: "SBJFoundationMacros",
    type: "SBJUnitValueMacro"
)
