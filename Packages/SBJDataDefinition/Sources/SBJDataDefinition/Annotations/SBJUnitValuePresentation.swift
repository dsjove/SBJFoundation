import Foundation

/// Selects whether a presentation may change a measurement’s unit.
/// This annotation changes no structural or validation semantics.
@attached(peer)
public macro SBJUnitValuePresentation(_ mode: SBJUnitValuePresentationMode = .fixedUnit) = #externalMacro(
    module: "SBJDataDefinitionMacros", type: "SBJUnitValuePresentationMacro"
)

public enum SBJUnitValuePresentationMode: String, Codable, Sendable, Hashable {
    case fixedUnit
    case editable
}
