/// Adds numeric constraints to a `UnitValue` property declared by `@SBJStructure`.
/// The unit remains part of the value; constraints apply to its numeric amount.
public enum SBJUnitValueEditorMode: Sendable, Hashable {
    case editable
    /// Edit the numeric amount while displaying the current unit as plain text.
    case fixedUnit
}

@attached(peer)
public macro SBJUnitValue(min: Double? = nil, editor: SBJUnitValueEditorMode = .editable) = #externalMacro(
    module: "SBJFoundationMacros",
    type: "SBJUnitValueMacro"
)
