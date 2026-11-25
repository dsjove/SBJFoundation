import SBJStructure
import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Repairs an explicitly constrained dictionary key without overwriting another entry.
struct SBJDictionaryKeyEditor<Key: Hashable, Value>: View {
    let key: Key
    @Binding var parent: [Key: Value]
    let registry: SBJEditorRegistry
    let constraints: SBJConstraintProjection
    let context: SBJEditTraversalContext
    @State private var draft: Key
    @State private var collision = false

    init(key: Key, parent: Binding<[Key: Value]>, registry: SBJEditorRegistry,
         constraints: SBJConstraintProjection, context: SBJEditTraversalContext) {
        self.key = key; _parent = parent; self.registry = registry
        self.constraints = constraints; self.context = context
        _draft = State(initialValue: key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SBJValueEditor.makeView(label: "Key", value: $draft, registry: registry,
                    constraints: constraints, context: context)
                if draft != key {
                    SBJApplyButton(accessibilityLabel: "Apply dictionary key") {
                        var snapshot = parent
                        guard snapshot.sbjReplaceKey(key, with: draft) else {
                            collision = true; return
                        }
                        parent = snapshot
                        collision = false
                    }
                    .disabled(constraints.scalarValidationError(for: draft) != nil)
                }
            }
            if collision { Text("That key already exists or the entry is no longer available.").font(.caption) }
        }
        .onChange(of: key) { _, new in draft = new; collision = false }
        .onChange(of: draft) { _, _ in collision = false }
    }
}
#endif
