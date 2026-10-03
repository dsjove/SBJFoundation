/// Adds integer constraints to a coded property handled by `@SBJStructure`.
/// An ordinary integer property requires no annotation.
///
/// A closed `range` constrains both bounds. `min` constrains only the lower
/// bound. These are invariant rules, not input restrictions; the generic editor
/// continues to allow out-of-range values so they can be inspected and repaired.
@attached(peer)
public macro SBJInteger(range: ClosedRange<Int>) = #externalMacro(
    module: "SBJFoundationMacros",
    type: "SBJIntegerMacro"
)

@attached(peer)
public macro SBJInteger(min: Int) = #externalMacro(
    module: "SBJFoundationMacros",
    type: "SBJIntegerMacro"
)
