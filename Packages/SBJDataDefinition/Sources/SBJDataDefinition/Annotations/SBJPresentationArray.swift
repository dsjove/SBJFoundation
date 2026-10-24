import Foundation

/// An optional key path selecting display titles for elements in an array.
@attached(peer)
public macro SBJPresentationArray(title: AnyKeyPath? = nil) = #externalMacro(module: "SBJDataDefinitionMacros", type: "SBJPresentationArrayMacro")
