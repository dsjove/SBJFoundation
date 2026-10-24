import SBJDataDefinition
import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import SwiftUI

@MainActor
struct SBJAssociatedEnumEditor<Value: SBJStructuredEnum>: View {
    let label: String
    @Binding var value: Value
    let originalValue: Value?
    let registry: SBJEditorRegistry
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    let context: SBJEditTraversalContext
    private var selectedCase: SBJEditorEnumCase<Value>? {
        Value.sbjStructuralEditorCases.first(where: { $0.matches(value) })
    }

    var rowStatus: SBJEditorRowStatus = .init()

    // Associated values are rendered by the flat traversal, not nested here.
    var body: some View {
        HStack(spacing: 8) {
            SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
                .accessibilityHidden(true)
            SBJSelectionMenu(
                selection: Binding<Int?>(
                    get: { Value.sbjStructuralEditorCases.firstIndex(where: { $0.matches(value) }) },
                    set: { index in
                        guard let index, Value.sbjStructuralEditorCases.indices.contains(index),
                              let replacement = Value.sbjStructuralEditorCases[index].makeDefaultValue()
                        else { return }
                        value = replacement
                    }
                ),
                choices: Value.sbjStructuralEditorCases.enumerated().map {
                    SBJMenuChoice(id: $0.offset, title: $0.element.name, isEnabled: $0.element.canCreate)
                },
                currentTitle: selectedCase?.name ?? String(describing: value),
                invalidSelection: selectedCase == nil
            )
            .sbjEditorAccessibleControl(label: label, status: rowStatus)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
