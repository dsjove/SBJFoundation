import Foundation

/// Declares an allowed Date range for an `@SBJStructure` property.
///
/// Date properties require no annotation for structural participation or native
/// date editing. The range is checked only when validation is explicitly requested;
/// the generic editor does not restrict the values a user can enter.
@attached(peer)
public macro SBJDate(range: ClosedRange<Date>) = #externalMacro(
    module: "SBJStructureMacros",
    type: "SBJDateMacro"
)
