import Foundation

/// Selects whether a presentation may change a measurement’s unit.
/// This annotation changes no structural or validation semantics.
@attached(peer)
public macro SBJPresentationUnit(_ mode: SBJPresentationUnitMode = .fixedUnit) = #externalMacro(
    module: "SBJDataDefinitionMacros", type: "SBJPresentationUnitMacro"
)

public enum SBJPresentationUnitMode: Sendable, Hashable {
    case fixedUnit
    case editable
}
