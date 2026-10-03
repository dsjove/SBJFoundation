/// Excludes a stored property from `SBJCodableEditor` field generation.
///
/// The property remains part of `@SBJStructure` structural metadata, content
/// inspection, and explicit invariant validation. Use this marker when a coded
/// writable property belongs to the model declaration but should not be edited by
/// the generic editor. Immutable `let` properties are already non-editable.
@attached(peer)
public macro SBJNotEditable() = #externalMacro(
    module: "SBJFoundationMacros",
    type: "SBJNotEditableMacro"
)
