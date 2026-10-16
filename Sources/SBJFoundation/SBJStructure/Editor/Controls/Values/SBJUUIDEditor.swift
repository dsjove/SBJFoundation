#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI
import SBJLocalization

struct SBJUUIDEditor: View {
    let label: String
    @Binding var value: UUID
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @State private var text = ""
    @State private var isValid = true
    @FocusState private var isFocused: Bool

    var rowStatus: SBJEditorRowStatus = .init()

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            TextField("", text: Binding(
                get: { text },
                set: { newValue in
                    text = newValue
                    if let parsed = newValue.sbjUUID {
                        value = parsed
                        isValid = true
                    } else {
                        isValid = false
                    }
                }
            ))
            .oneLiner(isFocused: $isFocused)
                .sbjEditorAccessibleControl(label: label, status: rowStatus)
            .invalidDecoration(!isValid)
#if os(iOS)
            .textInputAutocapitalization(.characters)
#endif
            SBJImageButton(
                SBJSymbology.regenerate,
                accessibilityLabel: "Generate new \(label)"
            ) {
                value = UUID()
                text = value.uuidString
                isValid = true
            }
        }
        .accessibilityValue(value.uuidString)
        .onAppear {
            text = value.uuidString
            focusRequest?.claim($isFocused)
        }
        .onChange(of: value) { _, newValue in
            // An external model update must not leave an unfocused field stale.
            // Preserve the user's draft while the control has focus.
            if !isFocused {
                text = newValue.uuidString
                isValid = true
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                text = value.uuidString
                isValid = true
            }
        }
    }

}
#endif
