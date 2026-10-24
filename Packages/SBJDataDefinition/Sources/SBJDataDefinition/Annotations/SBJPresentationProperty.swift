import Foundation

/// Marks a computed property as explicitly available to presentation consumers.
@attached(peer)
public macro SBJPresentationProperty() = #externalMacro(module: "SBJDataDefinitionMacros", type: "SBJPresentationPropertyMacro")
