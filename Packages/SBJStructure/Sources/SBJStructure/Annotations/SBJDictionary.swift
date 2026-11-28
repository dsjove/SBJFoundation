/// Adds Dictionary business rules and editor presentation metadata in `@SBJStructure`.
/// An ordinary Dictionary requires no annotation.
///
/// `minCount` and `maxCount` constrain entry count when validation is explicitly
/// requested. Editors do not edit keys directly. Insertion requires an explicit key generator;
/// key collisions are rejected rather than silently replacing an existing entry.
/// `elementName` selects the semantic name of a dictionary value.
@attached(peer)
public macro SBJDictionary(
    elementName: (AnyKeyPath & Sendable)? = nil,
    minCount: Int? = nil,
    maxCount: Int? = nil,
    key: [any SBJDictionaryMemberRule] = [],
    value: [any SBJDictionaryMemberRule] = []
) = #externalMacro(module: "SBJStructureMacros", type: "SBJDictionaryMacro")

/// Supplies a typed key generator for editor insertion. The generator receives the
/// current dictionary and the newly constructed value, and may return nil.
/// Specify closure parameter types (or pass a typed function) for generic inference.
@attached(peer)
public macro SBJDictionary<Key: Hashable, Value>(
    elementName: (AnyKeyPath & Sendable)? = nil,
    minCount: Int? = nil,
    maxCount: Int? = nil,
    key: [any SBJDictionaryMemberRule] = [],
    value: [any SBJDictionaryMemberRule] = [],
    keyGenerator: @escaping ([Key: Value], Value) -> Key?
) = #externalMacro(module: "SBJStructureMacros", type: "SBJDictionaryMacro")
