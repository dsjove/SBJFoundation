import SBJUIVocabulary
import SBJUnits
/// Editor-only text entry configuration; structural constraints belong to @SBJString.
@attached(peer)
public macro SBJEditorString(
    _ style: SBJStringStyle = .singleLine,
    autocorrect: SBJTextAutocorrection = .automatic,
    capitalization: SBJTextCapitalization = .automatic
) = #externalMacro(module: "SBJStructuredEditorMacros", type: "SBJEditorStringMacro")
