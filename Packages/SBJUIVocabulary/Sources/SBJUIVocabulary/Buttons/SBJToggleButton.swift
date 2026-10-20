import SwiftUI
import SBJDataDefinition
import SBJLocalization

/// Compact binary control using the shared SBJ active-control chrome.
///
/// The control owns selection presentation, the Differentiate Without Color
/// cue, label typography, and button style. Callers provide only the semantic
/// label, state, optional leading content, and accessibility wording.
// TODO: editor only?
@MainActor
public struct SBJToggleButton<Leading: View>: View {
    private let title: String
    @Binding private var isOn: Bool
    private let accessibilityLabel: String
    private let leading: Leading
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    public init(
        _ title: String,
        isOn: Binding<Bool>,
        accessibilityLabel: String,
        @ViewBuilder leading: () -> Leading
    ) {
        self.title = title
        self._isOn = isOn
        self.accessibilityLabel = accessibilityLabel
        self.leading = leading()
    }

    public var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 4) {
                if differentiateWithoutColor && isOn {
                    Image(symbol: SBJSymbology.selected)
                        .font(.caption.weight(.semibold))
                }
                leading
                Text(title)
                    .font(.caption)
            }
            .sbjActiveControl(isSelected: isOn, verticalPadding: 0)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibilityLabel)
    }
}
