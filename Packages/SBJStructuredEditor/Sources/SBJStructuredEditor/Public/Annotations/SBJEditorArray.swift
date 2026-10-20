import SBJUIVocabulary
import SBJUnits
/// Editor-only item heading selector.
@attached(peer)
public macro SBJEditorArray(title: AnyKeyPath? = nil) = #externalMacro(module: "SBJStructuredEditorMacros", type: "SBJEditorArrayMacro")
