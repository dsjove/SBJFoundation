/// Adds an owner-level presence requirement to an optional coded property.
/// An ordinary Optional requires no annotation.
@attached(peer)
public macro SBJOptional(required: Bool = true) = #externalMacro(
    module: "SBJFoundationMacros",
    type: "SBJOptionalMacro"
)
