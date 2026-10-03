#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJDataEditor: View {
    let label: String
    @Binding var value: Data
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @State private var text = ""
    @State private var errorMessage: String?
    @Environment(\.locale) private var locale
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
                    .accessibilityHidden(true)
                Spacer()
                Text(byteCountDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextEditor(text: Binding(
                get: { text },
                set: { newValue in
                    text = newValue
                    do {
                        value = try newValue.sbjHexData()
                        errorMessage = nil
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            ))
            .font(.system(.body, design: .monospaced))
            .sbjMultilineField(isFocused: $isFocused, minHeight: 90)
            .sbjEditorAccessibleControl(label: label)
            .invalidDecoration(errorMessage != nil)
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(SBJUIAppearance.invalidColor)
            }
        }
        .accessibilityValue(byteCountDescription)
        .onAppear {
            text = value.sbjHexFormat()
            focusRequest?.claim($isFocused)
        }
        .onChange(of: isFocused) { _, focused in
            if !focused, errorMessage == nil {
                text = value.sbjHexFormat()
            }
        }
    }

    private var byteCountDescription: String {
        let count = value.count.formatted(.number.locale(locale))
        // The numeric portion is locale-aware now. The noun itself moves to the
        // framework localization resources in the localization pass.
        return value.count == 1 ? "\(count) byte" : "\(count) bytes"
    }
}
#endif
