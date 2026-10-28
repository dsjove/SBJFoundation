import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJDecimalEditor: View {
    let label: String
    @Binding var value: Decimal
    let range: ClosedRange<Double>?
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @Environment(\.locale) private var locale
    @State private var draft = SBJParsedTextDraft()
    @FocusState private var isFocused: Bool

    var rowStatus: SBJEditorRowStatus = .init()

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            TextField("", text: Binding(
                get: { draft.text },
                set: { newValue in
                    if let parsed = draft.edit(newValue, parse: { parsedDecimal($0) }) {
                        value = parsed
                    }
                }
            ))
            .sbjSingleLineField(isFocused: $isFocused)
                .sbjEditorAccessibleControl(label: label, status: rowStatus)
            .sbjPreferredFieldWidth(SBJNumericFieldSizing.number(range: range, locale: locale))
            .invalidDecoration(
                !draft.isValid || (range.map { !$0.contains(NSDecimalNumber(decimal: value).doubleValue) } ?? false)
            )
#if os(iOS)
            .keyboardType(.decimalPad)
#endif
        }
        .onAppear {
            draft.reset(to: formattedDecimal(value))
            focusRequest?.claim($isFocused)
        }
        .onChange(of: value) { _, newValue in
            // An external model update must not leave an unfocused field stale.
            // Preserve the user's draft while the control has focus.
            if !isFocused {
                draft.reset(to: formattedDecimal(newValue))
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                draft.reset(to: formattedDecimal(value))
            }
        }
        .onChange(of: locale.identifier) { _, _ in
            if !isFocused {
                draft.reset(to: formattedDecimal(value))
            }
        }
    }

    private func formatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true
        return formatter
    }

    private func parsedDecimal(_ text: String) -> Decimal? {
        formatter().number(from: text)?.decimalValue
    }

    private func formattedDecimal(_ value: Decimal) -> String {
        formatter().string(from: NSDecimalNumber(decimal: value))
            ?? NSDecimalNumber(decimal: value).stringValue
    }
}
#endif
