#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJIntegerEditor: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>?
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            NumberTextField("", value: $value, in: range, isFocused: $isFocused)
                .sbjEditorAccessibleControl(label: label)
            stepper
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel("Adjust \(label)")
        }
        .onAppear(perform: claimFocus)
    }

    @ViewBuilder
    private var stepper: some View {
        if let range {
            Stepper("", value: $value, in: range)
        } else {
            Stepper("", value: $value)
        }
    }

    private func claimFocus() {
        focusRequest?.claim($isFocused)
    }
}
#endif
