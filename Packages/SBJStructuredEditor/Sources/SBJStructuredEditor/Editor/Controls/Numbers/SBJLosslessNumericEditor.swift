import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

/// Locale-aware editor for the fixed-width integer types that do not have a
/// dedicated SwiftUI `TextField(value:format:)` specialization in SBJStructure.
///
/// The model remains a normal Swift integer. Locale only affects presentation
/// and parsing at the editor boundary; no localized string is stored.
struct SBJLosslessNumericEditor<Value: FixedWidthInteger & LosslessStringConvertible>: View {
    let label: String
    @Binding var value: Value
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @Environment(\.locale) private var locale
    @State private var draft = SBJParsedTextDraft()
    @FocusState private var isFocused: Bool

    var rowStatus: SBJEditorRowStatus = .init()

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            TextField("", text: Binding(
                get: { draft.text.isEmpty && !isFocused ? formatted(value) : draft.text },
                set: { newValue in
                    if let parsed = draft.edit(newValue, parse: { parsedValue($0) }) {
                        value = parsed
                    }
                }
            ))
            .sbjSingleLineField(isFocused: $isFocused)
                .sbjEditorAccessibleControl(label: label, status: rowStatus)
            .sbjPreferredFieldWidth(SBJNumericFieldSizing.unboundedInteger)
            .invalidDecoration(!draft.isValid)
#if os(iOS)
            .keyboardType(.numbersAndPunctuation)
#endif
        }
        .onAppear {
            draft.reset(to: formatted(value))
            focusRequest?.claim($isFocused)
        }
        .onChange(of: value) { _, newValue in
            // An external model update must not leave an unfocused field stale.
            // Preserve the user's draft while the control has focus.
            if !isFocused {
                draft.reset(to: formatted(newValue))
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                draft.reset(to: formatted(value))
            }
        }
        .onChange(of: locale.identifier) { _, _ in
            if !isFocused {
                draft.reset(to: formatted(value))
            }
        }
    }

    private func numberFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.generatesDecimalNumbers = true
        return formatter
    }

    private func parsedValue(_ text: String) -> Value? {
        guard let number = numberFormatter().number(from: text) else { return nil }
        return Value(number.stringValue)
    }

    private func formatted(_ value: Value) -> String {
        // `String(value)` is a machine-stable bridge into Foundation. It is not
        // shown to the user; NumberFormatter produces the locale-facing value.
        guard let number = Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX"))
            .map(NSDecimalNumber.init(decimal:)) else {
            return String(value)
        }
        return numberFormatter().string(from: number) ?? String(value)
    }
}
#endif
