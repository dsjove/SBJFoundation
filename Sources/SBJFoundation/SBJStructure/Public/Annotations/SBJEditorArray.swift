/// Editor-only item heading selector.
@attached(peer)
public macro SBJEditorArray(title: AnyKeyPath? = nil) = #externalMacro(module: "SBJFoundationMacros", type: "SBJEditorArrayMacro")
