/// Adds Data byte-count business rules. Plain Data already participates in
/// `@SBJStructure` and receives hex editor support without an annotation.
///
/// `min` and `max` are byte counts. When supplied, `modulo` requires the byte
/// count to be evenly divisible by that positive value. Rules are enforced only
/// when an SBJStructure consumer explicitly validates the model.
@attached(peer)
public macro SBJData(
    min: Int? = nil,
    max: Int? = nil,
    modulo: Int? = nil
) = #externalMacro(module: "SBJFoundationMacros", type: "SBJDataMacro")
