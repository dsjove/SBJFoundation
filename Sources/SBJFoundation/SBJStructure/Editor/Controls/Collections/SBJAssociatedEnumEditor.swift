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
    @Environment(\.sbjEditorSearchCriteria) private var searchCriteria

    private var selectedCase: SBJEditorEnumCase<Value>? {
        Value.sbjEditorEnumCases.first(where: { $0.matches(value) })
    }

    private var originalForSelectedCase: Value? {
        guard let originalValue, let selectedCase else { return nil }
        return selectedCase.matches(originalValue) ? originalValue : nil
    }


    private func associatedValueSnapshot(
        _ selectedCase: SBJEditorEnumCase<Value>
    ) -> [SBJEditorSnapshotItem<SBJEditorAssociatedValue<Value>>] {
        selectedCase.associatedValues.enumerated().map { offset, field in
            SBJEditorSnapshotItem(
                itemIdentifier: context.itemIdentifier
                    .appending("case:\(selectedCase.name)")
                    .appending("property:\(field.name)"),
                indexPath: context.indexPath.appending("field:\(offset)"),
                content: field
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                    SBJCompactMenuLabel(text: selectedCase?.name ?? "Unknown")
                }
                .controlSize(.mini)
                .fixedSize()
                .sbjActiveControl(horizontalPadding: 4, verticalPadding: 0)
                .sbjEditorAccessibleControl(label: label)
                Spacer(minLength: 0)
            }

            if let selectedCase, !selectedCase.associatedValues.isEmpty {
                let childSearchCriteria = searchCriteria.descendingPastMatchedLabels(label, selectedCase.name)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(associatedValueSnapshot(selectedCase)) { item in
                        let field = item.content
                        field.view(
                            root: $value,
                            originalRoot: originalForSelectedCase,
                            registry: registry,
                            focusRequest: focusRequest,
                            context: SBJEditTraversalContext(
                                treeLevel: context.treeLevel + 1,
                                itemIdentifier: item.itemIdentifier,
                                indexPath: item.indexPath,
                                navigationPath: context.navigationPath + [field.name]
                            )
                        )
                    }
                }
                .environment(\.sbjEditorSearchCriteria, childSearchCriteria)
                .frame(maxWidth: .infinity)

                SBJEditorLevelExitDivider()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
