/// Adds Array business rules and editor presentation hints to a coded property in `@SBJStructure`.
/// An ordinary Array requires no annotation.
///
/// Arrays preserve their stored order. Editor reordering controls belong in
/// `@SBJArrayPresentation`; no rule automatically sorts or mutates an array.
/// `title` is a compiler-checked key path to the element property used as its
/// heading. `unique` requires Hashable elements; `uniqueBy` declares uniqueness
/// by a compiler-checked key path on the element. Use one uniqueness form at a time.
@attached(peer)
public macro SBJArray(
    minCount: Int? = nil,
    maxCount: Int? = nil,
    sorted: SBJSortDirection? = nil,
    unique: Bool = false,
    uniqueBy: AnyKeyPath? = nil
) = #externalMacro(module: "SBJDataDefinitionMacros", type: "SBJArrayMacro")
