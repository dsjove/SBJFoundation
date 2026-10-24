import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Destructive collection removal, confirmed before the model is mutated.
@MainActor
struct SBJConfirmedRemoveButton: View {
    let accessibilityLabel: String
    let remove: () -> Void
    @State private var askingToRemove = false

    var body: some View {
        SBJSymbolButton(
            SBJSymbology.remove,
            role: .destructive,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: "Asks for confirmation before removing this item"
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
