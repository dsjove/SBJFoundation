#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJUUIDEditor: View {
    let label: String
    @Binding var value: UUID
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @State private var text = ""
    @State private var isValid = true
    @FocusState private var isFocused: Bool

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
                .sbjEditorAccessibleControl(label: label)
            .invalidDecoration(!isValid)
#if os(iOS)
            .textInputAutocapitalization(.characters)
#endif
            SBJImageButton(
                SBJSemanticImageReference.regenerate,
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
        .onChange(of: isFocused) { _, focused in
            if !focused {
                text = value.uuidString
                isValid = true
            }
        }
    }

}
#endif
