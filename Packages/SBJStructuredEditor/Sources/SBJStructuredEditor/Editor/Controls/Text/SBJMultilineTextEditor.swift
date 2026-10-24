import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJMultilineTextEditor: View {
    let label: String
    @Binding var value: String
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @FocusState private var isFocused: Bool

    var rowStatus: SBJEditorRowStatus = .init()
    var textAutocorrection: SBJTextAutocorrection = .automatic
    var textCapitalization: SBJTextCapitalization = .automatic

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
                .accessibilityHidden(true)
            TextEditor(text: $value)
                .sbjMultilineField(isFocused: $isFocused, minHeight: 84)
                .sbjApplyTextInputPolicies(
                autocorrection: textAutocorrection,
                capitalization: textCapitalization
            )
                .sbjEditorAccessibleControl(label: label, status: rowStatus)
        }
        .onAppear(perform: claimFocus)
    }

    private func claimFocus() {
        focusRequest?.claim($isFocused)
    }
}
#endif
