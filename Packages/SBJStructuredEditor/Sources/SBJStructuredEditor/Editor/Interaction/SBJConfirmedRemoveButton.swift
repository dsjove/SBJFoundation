import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Destructive collection removal, confirmed before the model is mutated.
@MainActor
struct SBJConfirmedRemoveButton: View {
    let context: String
    let remove: () -> Void
    @State private var askingToRemove = false

    var body: some View {
        SBJSymbolButton(
            SBJStructuredEditorNomenclature.removeConfirmed,
            context: context,
            role: .destructive
        ) {
            askingToRemove = true
        }
        .confirmationDialog(
            "Remove this item?",
            isPresented: $askingToRemove,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive, action: remove)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This item will be removed from the collection.")
        }
    }
}
#endif
