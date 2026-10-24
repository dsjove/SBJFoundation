import Foundation

/// An optional key path selecting display titles for elements in a set.
@attached(peer)
public macro SBJPresentationSet(title: AnyKeyPath? = nil) = #externalMacro(module: "SBJDataDefinitionMacros", type: "SBJPresentationSetMacro")
