/// Adds floating-point constraints to a structural property handled by `@SBJStructure`.
/// An ordinary floating-point property requires no annotation.
///
/// A closed `range` constrains both bounds. `min` constrains only the lower
/// bound.
@attached(peer)
public macro SBJNumber(range: ClosedRange<Double>) = #externalMacro(
    module: "SBJStructureMacros",
    type: "SBJNumberMacro"
)

@attached(peer)
public macro SBJNumber(min: Double) = #externalMacro(
    module: "SBJStructureMacros",
    type: "SBJNumberMacro"
)

/// Constrains only the inclusive upper bound.
@attached(peer)
public macro SBJNumber(max: Double) = #externalMacro(module: "SBJStructureMacros", type: "SBJNumberMacro")

/// Constrains both inclusive bounds without constructing a range.
@attached(peer)
public macro SBJNumber(min: Double, max: Double) = #externalMacro(module: "SBJStructureMacros", type: "SBJNumberMacro")
