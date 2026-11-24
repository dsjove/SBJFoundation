import Foundation

/// Reusable, UI-independent configuration for presenting a model field.
public struct SBJFieldPresentationValue: Codable, Sendable, Equatable {
    public var autoExpand: Bool
    public var exclude: Bool

    public init(autoExpand: Bool = false, exclude: Bool = false) {
        self.autoExpand = autoExpand
        self.exclude = exclude
    }
}

/// Configures field presentation without changing its data rules or validation.
@attached(peer)
public macro SBJFieldPresentation(
    autoExpand: Bool = false,
    exclude: Bool = false
) = #externalMacro(module: "SBJStructureMacros", type: "SBJFieldPresentationMacro")
