import SBJStructure
import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// A compound business value occupies one row. Its canonical member editors
/// remain available in a separate editing surface, using the same bindings and rules.
@MainActor
struct SBJAtomicValueEditor<Value>: View {
    let label: String
    @Binding var value: Value
    let registry: SBJEditorRegistry
    let showsReadOnlyProperties: Bool
    @State private var isEditing = false
    @State private var detailModel = SBJEditorPresentationModel()

    private var detailContext: SBJEditTraversalContext {
        .root.withBranch(.init(showsReadOnlyProperties: showsReadOnlyProperties))
    }

    private var detailRows: [SBJEditorTraversalNode] {
        let binding = SBJAnyBinding($value)
        let roots: [SBJEditorTraversalNode]
        if let enumeration = Value.self as? any SBJStructuredEnum.Type {
            roots = enumeration._sbjBoundAssociatedTraversalNodes(binding: binding, registry: registry, context: detailContext)
        } else if let structure = Value.self as? any SBJMutableStructure.Type {
            roots = structure._sbjStructuralBoundNodes(binding: binding, originalValue: nil, registry: registry, context: detailContext)
        } else {
            roots = []
        }
        return sbjEditorRows(roots: roots, presentationModel: detailModel)
    }

    var body: some View {
        HStack {
            SBJEditorFieldName(text: label, isUnknown: false)
            Spacer(minLength: 0)
            Button {
                isEditing = true
            } label: {
                Text((value as? any SBJAtomicStructuralValue)?.presentedValue ?? "—")
            }
            .accessibilityLabel(label)
            .popover(isPresented: $isEditing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if let enumeration = Value.self as? any SBJStructuredEnum.Type {
                            enumeration._sbjMakeAssociatedEnumEditor(label: label,
                                binding: SBJAnyBinding($value), registry: registry, context: detailContext)
                        }
                        ForEach(detailRows) { row in
                            if let rendered = row.renderedRow() { rendered }
                            ForEach(Array(row.endDividerLevels.enumerated()), id: \.offset) { entry in
                                SBJEditorGroupEnd(indentLevel: entry.element)
                            }
                        }
                        Button("Done") { isEditing = false }
                    }
                    .padding()
                }
                .frame(minWidth: 280, idealWidth: 360, minHeight: 100, idealHeight: 260)
                .environment(detailModel)
            }
        }
    }
}
#endif
