import SBJLocalization
import SwiftUI

/// Compact binary control using the shared SBJ active-control chrome.
///
/// The control owns selection presentation, the Differentiate Without Color
/// cue, label typography, and button style. Callers provide only the semantic
/// label, state, optional leading content, and accessibility wording.
@MainActor
public struct SBJToggleButton<Leading: View>: View {
    private let title: String
    @Binding private var isOn: Bool
    private let accessibilityLabel: String
    private let accessibilityHint: String?
    private let leading: Leading
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    public init(
        _ nomenclature: SBJNomenclature,
        isOn: Binding<Bool>,
        @ViewBuilder leading: () -> Leading
    ) {
        precondition(!(nomenclature.accessibilityLabel ?? nomenclature.title).isEmpty,
                     "A toggle requires an accessible name")
        self.title = nomenclature.title
        self._isOn = isOn
        self.accessibilityLabel = nomenclature.accessibilityLabel ?? nomenclature.title
        self.accessibilityHint = nomenclature.accessibilityHint ?? nomenclature.summary
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
        .accessibilityValue(isOn ? "On" : "Off")
        .applyIf(accessibilityHint) { view, hint in
            view.accessibilityHint(Text(verbatim: hint))
        }
    }
}
