import Foundation

/// Marks a property as excluded from automatic presentation; it remains part of the structural definition.
@attached(peer)
public macro SBJPresentationExclude() = #externalMacro(module: "SBJDataDefinitionMacros", type: "SBJPresentationExcludeMacro")
