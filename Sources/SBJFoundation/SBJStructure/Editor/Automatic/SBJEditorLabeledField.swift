#if !os(tvOS) && !os(watchOS)
import SwiftUI

private struct SBJEditorVisuallyIneffectiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Makes a field look disabled while deliberately leaving it interactive.
    /// Used when a stored request is valid but has no effect for the current value.
    var sbjEditorVisuallyIneffective: Bool {
        get { self[SBJEditorVisuallyIneffectiveKey.self] }
        set { self[SBJEditorVisuallyIneffectiveKey.self] = newValue }
    }
}

struct SBJEditorLabeledField<Control: View>: View {
    let label: String
    let labelIsUnknown: Bool
    let control: Control
    @Environment(\.sbjEditorVisuallyIneffective) private var visuallyIneffective

    init(
        label: String,
        labelIsUnknown: Bool,
        @ViewBuilder control: () -> Control
    ) {
        self.label = label
        self.labelIsUnknown = labelIsUnknown
        self.control = control()
    }

    var body: some View {
        SBJAdaptiveFieldLayout {
            SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
                .accessibilityHidden(true)
        } control: {
            control
        }
        // Opacity gives both the label and the native control their familiar
        // disabled appearance without changing hit testing or control state.
        .opacity(visuallyIneffective ? 0.5 : 1.0)
    }
}
#endif
