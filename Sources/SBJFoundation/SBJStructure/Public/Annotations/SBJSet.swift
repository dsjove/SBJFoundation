/// Adds Set business rules and editor presentation metadata in `@SBJStructure`.
/// An ordinary Set requires no annotation.
///
/// Sets are inherently unique and have no stored order, so there are no
/// uniqueness or reordering options. Editors present members deterministically,
/// preferring a natural order where SBJStructure can identify one.
@attached(peer)
public macro SBJSet(
    title: AnyKeyPath? = nil,
    minCount: Int? = nil,
    maxCount: Int? = nil
) = #externalMacro(module: "SBJFoundationMacros", type: "SBJSetMacro")
