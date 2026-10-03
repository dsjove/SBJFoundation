#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJFontFamilyEditor: View {
    let label: String
    @Binding var value: String?
    let labelIsUnknown: Bool

    private var fontFamilies: [String] {
        let available = CodableFontCache.shared.availableFontFamilies
        guard let current = value, !available.contains(current) else {
            return available
        }
        return [current] + available
    }

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            Menu {
                Button("System") { value = nil }
                ForEach(fontFamilies, id: \.self) { family in
                    Button(family) { value = family }
                }
            } label: {
                SBJCompactMenuLabel(text: value ?? "System")
            }
            .controlSize(.mini)
            .fixedSize()
            .sbjActiveControl(horizontalPadding: 4, verticalPadding: 0)
            .sbjEditorAccessibleControl(label: label)
        }
    }
}
#endif
