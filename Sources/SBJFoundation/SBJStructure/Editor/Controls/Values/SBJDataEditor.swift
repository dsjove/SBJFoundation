#if !os(tvOS) && !os(watchOS)
import Foundation
import SBJDataDefinition
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

    var rowStatus: SBJEditorRowStatus = .init()

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
            .sbjEditorAccessibleControl(label: label, status: rowStatus)
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
        // Format the count for the current locale; the unit uses singular or plural wording.
        return value.count == 1 ? "\(count) byte" : "\(count) bytes"
    }
}
#endif
