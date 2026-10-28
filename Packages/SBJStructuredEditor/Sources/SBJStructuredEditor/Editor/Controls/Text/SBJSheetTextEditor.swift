import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import SwiftUI

struct SBJSheetTextEditor: View {
    let label: String
    @Binding var value: String
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool

    var rowStatus: SBJEditorRowStatus = .init()
    var presentation: SBJStringPresentationValue = .init(style: .sheetEdit)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
                .accessibilityHidden(true)
            PlaceholderMultilineTextField(
                label, text: $value, presentation: presentation,
                requestInitialFocus: { focusRequest?.claim() ?? false }
            )
                .sbjEditorAccessibleControl(label: label, status: rowStatus)
        }
    }
}
#endif
