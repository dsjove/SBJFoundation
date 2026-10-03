/// Adds floating-point constraints to a coded property handled by `@SBJStructure`.
/// An ordinary floating-point property requires no annotation.
///
/// A closed `range` constrains both bounds. `min` constrains only the lower
/// bound.
@attached(peer)
public macro SBJNumber(range: ClosedRange<Double>) = #externalMacro(
    module: "SBJFoundationMacros",
    type: "SBJNumberMacro"
)

@attached(peer)
public macro SBJNumber(min: Double) = #externalMacro(
    module: "SBJFoundationMacros",
    type: "SBJNumberMacro"
)
