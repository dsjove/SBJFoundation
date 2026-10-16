#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJFontFamilyEditor: View {
    let label: String
    @Binding var value: String?
    let labelIsUnknown: Bool

    var rowStatus: SBJEditorRowStatus = .init()

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            SBJSelectionMenu(
                selection: Binding<Int?>(
                    get: {
                        guard let value else { return 0 }
                        return CodableFontCache.shared.availableFontFamilies.firstIndex(of: value).map { $0 + 1 }
                    },
                    set: { index in
                        guard let index else { return }
                        if index == 0 { value = nil }
                        else {
                            let families = CodableFontCache.shared.availableFontFamilies
                            if families.indices.contains(index - 1) { value = families[index - 1] }
                        }
                    }
                ),
                choices: [SBJMenuChoice(id: 0, title: "System")] +
                    CodableFontCache.shared.availableFontFamilies.enumerated().map {
                        SBJMenuChoice(id: $0.offset + 1, title: $0.element)
                    },
                currentTitle: value ?? "System",
                invalidSelection: value.map { !CodableFontCache.shared.availableFontFamilies.contains($0) } ?? false
            )
            .sbjEditorAccessibleControl(label: label, status: rowStatus)
        }
    }
}
#endif
