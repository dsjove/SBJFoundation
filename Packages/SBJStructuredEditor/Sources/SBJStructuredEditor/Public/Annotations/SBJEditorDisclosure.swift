import SBJUIVocabulary
import SBJUnits
/// Default disclosure behavior for a structured editor property.
/// `.closed` starts collapsed; `.autoOpen` starts expanded but remains collapsible; `.alwaysOpen` is permanently
/// expanded and displays no disclosure button.
public enum SBJEditorDisclosureMode: Sendable, Hashable {
    case closed
    case autoOpen
    case alwaysOpen
}

/// Applies disclosure behavior to a property, not to the value's type.
@attached(peer)
public macro SBJEditorDisclosure(_ mode: SBJEditorDisclosureMode) = #externalMacro(
    module: "SBJStructuredEditorMacros", type: "SBJEditorDisclosureMacro"
)
