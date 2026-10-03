/// Adds Dictionary business rules and editor presentation metadata in `@SBJStructure`.
/// An ordinary Dictionary requires no annotation.
///
/// `minCount` and `maxCount` constrain entry count when validation is explicitly
/// requested. Editors may edit keys only when the key type itself has an editor;
/// key collisions are rejected rather than silently replacing an existing entry.
@attached(peer)
public macro SBJDictionary(
    minCount: Int? = nil,
    maxCount: Int? = nil
) = #externalMacro(module: "SBJFoundationMacros", type: "SBJDictionaryMacro")
