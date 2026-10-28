import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJSingleLineTextEditor: View {
    let label: String
    @Binding var value: String
    let maximumLength: Int?
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @FocusState private var isFocused: Bool

    var rowStatus: SBJEditorRowStatus = .init()
    var presentation: SBJStringPresentationValue = .init()

    var body: some View {
        SBJAdaptiveFieldLayout(
            controlWidth: .singleLineText(maximumLength: maximumLength)
        ) {
            SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
                .accessibilityHidden(true)
        } control: {
            field
        }
        .onAppear(perform: claimFocus)
    }

    @ViewBuilder
    private var field: some View {
        let base = TextField("", text: $value)
            .sbjSingleLineField(isFocused: $isFocused)
            .sbjTextInput(presentation)
            .sbjEditorAccessibleControl(label: label, status: rowStatus)

        if let sizing = SBJTextFieldSizing.singleLine(maximumLength: maximumLength) {
            base.sbjPreferredFieldWidth(sizing)
        } else {
            base
        }
    }

    private func claimFocus() {
        focusRequest?.claim($isFocused)
    }
}
#endif
