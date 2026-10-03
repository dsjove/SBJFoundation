#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJDoubleEditor: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>?
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @Environment(\.locale) private var locale
    @FocusState private var isFocused: Bool

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            TextField("", value: $value, format: .number)
                .oneLiner(isFocused: $isFocused)
                .sbjEditorAccessibleControl(label: label)
                .sbjPreferredFieldWidth(SBJNumericFieldSizing.number(range: range, locale: locale))
                .invalidDecoration(range.map { !$0.contains(value) } ?? false)
#if os(iOS)
                .keyboardType(.decimalPad)
#endif
        }
        .onAppear(perform: claimFocus)
    }

    private func claimFocus() {
        focusRequest?.claim($isFocused)
    }
}
#endif
