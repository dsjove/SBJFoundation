import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJURLEditor: View {
    let label: String
    @Binding var value: URL
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @State private var draft = SBJParsedTextDraft()
    @FocusState private var isFocused: Bool

    private var parsedURL: URL? {
        draft.text.sbjURL
    }

    private var openableURL: URL? {
        guard let parsedURL, parsedURL.scheme != nil else { return nil }
        return parsedURL
    }

    var rowStatus: SBJEditorRowStatus = .init()

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            TextField("", text: Binding(
                get: { draft.text },
                set: { newValue in
                    if let parsed = draft.edit(newValue, parse: { $0.sbjURL }) {
                        value = parsed
                    }
                }
            ))
            .sbjSingleLineField(isFocused: $isFocused)
                .sbjEditorAccessibleControl(label: label, status: rowStatus)
            .invalidDecoration(!draft.isValid)
#if os(iOS)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
#endif
            SBJURLButton(url: openableURL, accessibilityLabel: "Open \(label)")
        }
        .accessibilityValue(value.absoluteString)
        .onAppear {
            draft.reset(to: value.absoluteString)
            focusRequest?.claim($isFocused)
        }
        .onChange(of: value) { _, newValue in
            // An external model update must not leave an unfocused field stale.
            // Preserve the user's draft while the control has focus.
            if !isFocused {
                draft.reset(to: newValue.absoluteString)
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                draft.reset(to: value.absoluteString)
            }
        }
    }
}
#endif
