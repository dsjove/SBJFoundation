import SwiftUI
import SBJDataDefinition
import SBJLocalization

/// Compact disclosure control for expandable UI.
///
/// This view owns only the presentation and interaction of the disclosure
/// affordance. The surrounding container remains responsible for hierarchy,
/// row layout, content semantics, and whether this control should be hidden
/// from accessibility to avoid duplicate actions.
@MainActor
public struct SBJDisclosureButton: View {
    public let title: String
    @Binding private var isExpanded: Bool
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public init(_ title: String, isExpanded: Binding<Bool>) {
        self.title = title
        self._isExpanded = isExpanded
    }

    public var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            Image(symbol: SBJSymbology.disclosure(expanded: isExpanded))
                .font(.caption.weight(.semibold))
                .frame(
                    minWidth: SBJUIAppearance.compactButtonMinimumSize,
                    minHeight: SBJUIAppearance.compactButtonMinimumSize
                )
                .overlay {
                    Circle()
                        .stroke(
                            SBJUIAppearance.subtleStrokeColor(colorSchemeContrast),
                            lineWidth: SBJUIAppearance.borderThickness(colorSchemeContrast)
                        )
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse \(title)" : "Expand \(title)")
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }
}
