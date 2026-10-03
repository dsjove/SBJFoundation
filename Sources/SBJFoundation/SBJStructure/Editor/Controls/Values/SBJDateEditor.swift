#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJDateEditor: View {
    let label: String
    @Binding var value: Date
    let range: ClosedRange<Date>?
    let labelIsUnknown: Bool

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            DatePicker("", selection: $value)
                .labelsHidden()
                .fixedSize()
                .sbjEditorAccessibleControl(label: label)
        }
    }
}
#endif
