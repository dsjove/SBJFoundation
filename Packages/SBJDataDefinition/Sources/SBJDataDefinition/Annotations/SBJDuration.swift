import Foundation

/// Interprets an annotated Double (TimeInterval) as a nonnegative duration.
/// The range lists permitted displayed units; values are stored in seconds.
@attached(peer)
public macro SBJDuration(units: ClosedRange<DurationUnit> = .milliseconds ... .day) = #externalMacro(
    module: "SBJDataDefinitionMacros",
    type: "SBJDurationMacro"
)
