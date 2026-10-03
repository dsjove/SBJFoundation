#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJBooleanEditor: View {
    let label: String
    @Binding var value: Bool
    let labelIsUnknown: Bool

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            Toggle("", isOn: $value)
                .labelsHidden()
                .fixedSize()
                .sbjEditorAccessibleControl(label: label)
        }
    }
}
#endif
