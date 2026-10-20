import SBJUIVocabulary
import SBJUnits
/// Editor-only item heading selector.
@attached(peer)
public macro SBJEditorSet(title: AnyKeyPath? = nil) = #externalMacro(module: "SBJStructuredEditorMacros", type: "SBJEditorSetMacro")
