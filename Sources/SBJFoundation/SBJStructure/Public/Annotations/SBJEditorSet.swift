import SBJUIVocabulary
import SBJDataDefinition
/// Editor-only item heading selector.
@attached(peer)
public macro SBJEditorSet(title: AnyKeyPath? = nil) = #externalMacro(module: "SBJFoundationMacros", type: "SBJEditorSetMacro")
