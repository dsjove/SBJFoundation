/// Declares an additional UUID business rule for an `@SBJStructure` property.
///
/// UUID properties require no annotation for structural participation or smart
/// editing. Use this annotation only when the all-zero UUID is not valid.
@attached(peer)
public macro SBJUUID(nonzero: Bool = true) = #externalMacro(
    module: "SBJFoundationMacros",
    type: "SBJUUIDMacro"
)
