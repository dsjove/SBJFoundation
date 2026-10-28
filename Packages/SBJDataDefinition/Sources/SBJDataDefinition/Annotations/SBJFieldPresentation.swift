import Foundation

/// Reusable, UI-independent configuration for presenting a model field.
public struct SBJFieldPresentationValue: Codable, Sendable, Equatable {
    public var autoExpand: Bool
    public var exclude: Bool
    public var name: String?

    public init(autoExpand: Bool = false, exclude: Bool = false, name: String? = nil) {
        self.autoExpand = autoExpand
        self.exclude = exclude
        self.name = name
    }
}

/// Configures field presentation without changing its data rules or validation.
@attached(peer)
public macro SBJFieldPresentation(
    autoExpand: Bool = false,
    exclude: Bool = false,
    name: String? = nil
) = #externalMacro(module: "SBJDataDefinitionMacros", type: "SBJFieldPresentationMacro")
