/// Marks the initializer that `@SBJStructure` should use when exporting a value
/// as reconstructable Swift source.
///
/// The initializer declaration itself is the source of truth for argument order
/// and labels. Explicit designation takes precedence over automatically inferred
/// initializer metadata. Source reconstruction requires coverage of every coded
/// stored property; otherwise the encoder uses its closure or Codable fallback.
@attached(peer, names: named(sbjSwiftInitializerParameters))
public macro SBJDesignatedInit() = #externalMacro(
    module: "SBJDataDefinitionMacros",
    type: "SBJDesignatedInitMacro"
)
