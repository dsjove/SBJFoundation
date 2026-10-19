import Foundation

/// Adds String presentation and/or length information beyond the Swift type.
/// Unannotated `String` values already participate and default to `.singleLine`.
/// Length constraints are emitted into the containing type's generated `_invariant`.
@attached(peer)
public macro SBJString(
    minLength: Int? = nil,
    maxLength: Int? = nil,
    trimming: SBJStringTrimming = .none
) = #externalMacro(module: "SBJDataDefinitionMacros", type: "SBJStringMacro")
