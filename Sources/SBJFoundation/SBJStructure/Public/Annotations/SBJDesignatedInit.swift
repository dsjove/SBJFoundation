/// Marks the initializer that `@SBJStructure` should use when exporting a value
/// as reconstructable Swift source.
///
/// The initializer declaration itself is the source of truth for argument order
/// and labels. Parameter local names are matched to coded stored-property names.
/// Stored properties that are not represented by this initializer are omitted.
@attached(peer, names: named(sbjSwiftInitializerParameters))
public macro SBJDesignatedInit() = #externalMacro(
    module: "SBJFoundationMacros",
    type: "SBJDesignatedInitMacro"
)
