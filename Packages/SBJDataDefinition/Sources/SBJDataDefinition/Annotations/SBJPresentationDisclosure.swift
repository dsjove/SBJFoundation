import Foundation

/// Requests the initial disclosure policy for presentation consumers.
@attached(peer)
public macro SBJPresentationDisclosure(_ mode: SBJPresentationDisclosureMode) = #externalMacro(module: "SBJDataDefinitionMacros", type: "SBJPresentationDisclosureMacro")
