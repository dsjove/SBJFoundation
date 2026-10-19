#if !os(tvOS) && !os(watchOS)
import SwiftUI

import SBJDataDefinition
struct SBJSheetTextEditor: View {
    let label: String
    @Binding var value: String
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool

    var rowStatus: SBJEditorRowStatus = .init()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
                .accessibilityHidden(true)
            PlaceholderMultilineTextField(label, text: $value)
                .sbjEditorAccessibleControl(label: label, status: rowStatus)
        }
    }
}
#endif
