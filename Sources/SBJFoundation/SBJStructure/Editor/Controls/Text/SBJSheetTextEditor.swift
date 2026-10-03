#if !os(tvOS) && !os(watchOS)
import SwiftUI

struct SBJSheetTextEditor: View {
    let label: String
    @Binding var value: String
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
                .accessibilityHidden(true)
            PlaceholderMultilineTextField(label, text: $value)
                .sbjEditorAccessibleControl(label: label)
        }
    }
}
#endif
