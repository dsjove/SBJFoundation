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
    var headerOnly: Bool = false
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

    private func associatedValueRows(
        _ selectedCase: SBJEditorEnumCase<Value>
    ) -> [SBJEditorPresentationRow<SBJEditorAssociatedValue<Value>>] {
        sbjEditorPresentationRows(
            from: associatedValueSnapshot(selectedCase),
            parent: context,
            navigationPath: { $0.name },
            depthIncrement: 1
        )
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
                    SBJCompactMenuLabel(
                        text: selectedCase?.name ?? "Unknown",
                        options: Value.sbjEditorEnumCases.map(\.name)
                    )
                }
                .controlSize(.mini)
                .fixedSize()
                .sbjActiveControl(horizontalPadding: 4, verticalPadding: 0)
                .sbjEditorAccessibleControl(label: label)
                Spacer(minLength: 0)
            }

            if !headerOnly, let selectedCase, !selectedCase.associatedValues.isEmpty {
                let childSearchCriteria = searchCriteria.descendingPastMatchedLabels(label, selectedCase.name)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(associatedValueRows(selectedCase)) { row in
                        let field = row.content
                        field.view(
                            root: $value,
                            originalRoot: originalForSelectedCase,
                            registry: registry,
                            focusRequest: focusRequest,
                            context: row.context
                        )
                    }
                }
                .environment(\.sbjEditorSearchCriteria, childSearchCriteria)
                .frame(maxWidth: .infinity)

                SBJEditorLevelExitDivider(level: context.treeLevel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
