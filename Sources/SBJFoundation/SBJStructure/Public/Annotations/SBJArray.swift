/// Adds Array business rules and editor presentation hints to a coded property in `@SBJStructure`.
/// An ordinary Array requires no annotation.
///
/// Arrays preserve their stored order. `reorderable` controls whether an editor
/// may let the user change that stored order; it never causes automatic sorting.
/// `title` is a compiler-checked key path to the element property used as its
/// heading. `unique` requires Hashable elements; `uniqueBy` declares uniqueness
/// by a compiler-checked key path on the element. Use one uniqueness form at a time.
@attached(peer)
public macro SBJArray(
    reorderable: Bool = true,
    title: AnyKeyPath? = nil,
    minCount: Int? = nil,
    maxCount: Int? = nil,
    unique: Bool = false,
    uniqueBy: AnyKeyPath? = nil
) = #externalMacro(module: "SBJFoundationMacros", type: "SBJArrayMacro")
