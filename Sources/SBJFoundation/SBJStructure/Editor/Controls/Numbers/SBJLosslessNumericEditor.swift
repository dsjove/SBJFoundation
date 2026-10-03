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
    @State private var text: String = ""
    @State private var isValid = true
    @FocusState private var isFocused: Bool

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            TextField("", text: Binding(
                get: { text.isEmpty && !isFocused ? formatted(value) : text },
                set: { newValue in
                    text = newValue
                    if let parsed = parsedValue(newValue) {
                        value = parsed
                        isValid = true
                    } else {
                        isValid = false
                    }
                }
            ))
            .oneLiner(isFocused: $isFocused)
                .sbjEditorAccessibleControl(label: label)
            .sbjPreferredFieldWidth(SBJNumericFieldSizing.unboundedInteger)
            .invalidDecoration(!isValid)
#if os(iOS)
            .keyboardType(.numbersAndPunctuation)
#endif
        }
        .onAppear {
            text = formatted(value)
            focusRequest?.claim($isFocused)
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                text = formatted(value)
                isValid = true
            }
        }
        .onChange(of: locale.identifier) { _, _ in
            if !isFocused {
                text = formatted(value)
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
