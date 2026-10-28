/// Declares color-picker presentation metadata for `CodableColor`.
///
/// `CodableColor` properties require no annotation for structural participation or
/// color-picker editing. Use `alpha: false` when consumers should treat the color
/// as RGB-only and the standard editor should not expose an alpha control.
@attached(peer)
public macro SBJColorPresentation(alpha: Bool) = #externalMacro(
    module: "SBJDataDefinitionMacros",
    type: "SBJColorPresentationMacro"
)
