import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJUUIDEditor: View {
    let label: String
    @Binding var value: UUID
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @State private var draft = SBJParsedTextDraft()
    @FocusState private var isFocused: Bool

    var rowStatus: SBJEditorRowStatus = .init()

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            TextField("", text: Binding(
                get: { draft.text },
                set: { newValue in
                    if let parsed = draft.edit(newValue, parse: { $0.sbjUUID }) {
                        value = parsed
                    }
                }
            ))
            .sbjSingleLineField(isFocused: $isFocused)
                .sbjEditorAccessibleControl(label: label, status: rowStatus)
            .invalidDecoration(!draft.isValid)
#if os(iOS)
            .textInputAutocapitalization(.characters)
#endif
            SBJSymbolButton(
                SBJStructuredEditorSymbology.regenerate,
                accessibilityLabel: "Generate new \(label)"
            ) {
                value = UUID()
                draft.reset(to: value.uuidString)
            }
        }
        .accessibilityValue(value.uuidString)
        .onAppear {
            draft.reset(to: value.uuidString)
            focusRequest?.claim($isFocused)
        }
        .onChange(of: value) { _, newValue in
            // An external model update must not leave an unfocused field stale.
            // Preserve the user's draft while the control has focus.
            if !isFocused {
                draft.reset(to: newValue.uuidString)
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                draft.reset(to: value.uuidString)
            }
        }
    }

}
#endif
