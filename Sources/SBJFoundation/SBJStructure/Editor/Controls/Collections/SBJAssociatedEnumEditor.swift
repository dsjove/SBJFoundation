#if !os(tvOS) && !os(watchOS)
import SwiftUI

@MainActor
struct SBJAssociatedEnumEditor<Value: SBJEditableAssociatedEnum>: View {
    let label: String
    @Binding var value: Value
    let originalValue: Value?
    let registry: SBJEditorRegistry
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    let context: SBJEditTraversalContext
    private var selectedCase: SBJEditorEnumCase<Value>? {
        Value.sbjEditorEnumCases.first(where: { $0.matches(value) })
    }

    var rowStatus: SBJEditorRowStatus = .init()

    // Associated values are rendered by the flat traversal, not nested here.
    var body: some View {
        HStack(spacing: 8) {
            SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
                .accessibilityHidden(true)
            Menu {
                ForEach(Array(Value.sbjEditorEnumCases.enumerated()), id: \.offset) { _, enumCase in
                    Button(enumCase.name) {
                        if let replacement = enumCase.makeDefaultValue() {
                            value = replacement
                        }
                    }
                    .disabled(!enumCase.canCreate)
                }
            } label: {
                SBJCompactMenuLabel(
                    text: selectedCase?.name ?? "Unknown",
                    options: Value.sbjEditorEnumCases.map(\.name)
                )
            }
            .controlSize(.mini)
            .fixedSize()
            .sbjActiveControl(horizontalPadding: 4, verticalPadding: 0)
            .sbjEditorAccessibleControl(label: label, status: rowStatus)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
