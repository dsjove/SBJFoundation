#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJURLEditor: View {
    let label: String
    @Binding var value: URL
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @State private var text = ""
    @State private var isValid = true
    @FocusState private var isFocused: Bool

    private var parsedURL: URL? {
        text.sbjURL
    }

    private var openableURL: URL? {
        guard let parsedURL, parsedURL.scheme != nil else { return nil }
        return parsedURL
    }

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            TextField("", text: Binding(
                get: { text },
                set: { newValue in
                    text = newValue
                    if let parsed = newValue.sbjURL {
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
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
#endif
            URLButton(url: openableURL, accessibilityLabel: "Open \(label)")
        }
        .accessibilityValue(value.absoluteString)
        .onAppear {
            text = value.absoluteString
            focusRequest?.claim($isFocused)
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                text = value.absoluteString
                isValid = true
            }
        }
    }
}
#endif
