import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Pure accessibility wording used by generated field controls.
///
/// Keeping this outside the SwiftUI modifier makes the semantic contract unit-testable:
/// visual refactors must not silently drop changed, empty, or invalid state from the
/// accessibility representation.
struct SBJEditorAccessibilitySemantics {
    static func spokenLabel(
        label: String,
        isChanged: Bool,
        hasContent: Bool?,
        isInvalid: Bool
    ) -> String {
        var parts = [label]
        if isChanged { parts.append("changed") }
        if hasContent == false { parts.append("no content") }
        if isInvalid { parts.append("invalid") }
        return parts.joined(separator: ", ")
    }
}

private struct SBJEditorAccessibleControlModifier: ViewModifier {
    let label: String
    let status: SBJEditorRowStatus

    func body(content: Content) -> some View {
        content.accessibility(
            AccessibleItem(label: SBJEditorAccessibilitySemantics.spokenLabel(
                label: label,
                isChanged: status.isChanged,
                hasContent: status.hasContent,
                isInvalid: status.isInvalid
            ))
        )
    }
}

extension View {
    /// Gives the interactive editor control ownership of the visible field name
    /// and structural state. The separately rendered visual label should be
    /// hidden from accessibility when this modifier is used.
    func sbjEditorAccessibleControl(label: String, status: SBJEditorRowStatus = .init()) -> some View {
        modifier(SBJEditorAccessibleControlModifier(label: label, status: status))
    }
}
#endif
