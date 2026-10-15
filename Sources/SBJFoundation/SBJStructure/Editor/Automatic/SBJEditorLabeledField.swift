#if !os(tvOS) && !os(watchOS)
import SwiftUI

struct SBJEditorLabeledField<Control: View>: View {
    let label: String
    let labelIsUnknown: Bool
    let control: Control

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
                .allowsHitTesting(false)
        } control: {
            control
        }
        // Opacity gives both the label and the native control their familiar
        // disabled appearance without changing hit testing or control state.
    }
}
#endif
