import SwiftUI
import SBJDataDefinition
import SBJLocalization

@MainActor
public struct SBJDeleteButton: View {
    private let accessibilityLabel: String
    private let accessibilityHint: String?
    private let confirmationTitle: String?
    private let confirmationMessage: String?
    private let action: () -> Void

    @State private var showingConfirmation = false

    /// TODO(Localization): The title, confirmation sentence, noun, and optional
    /// extra text cannot be safely localized by concatenating independently
    /// translated strings. Migrate this initializer as a complete grammatical
    /// resource during the shared text-resource pass. See
    /// Documentation/LOCALIZATION_AND_PRESENTATION_RESOURCES.md.
    public init(
        _ noun: String,
        _ extra: String = "",
        accessibilityHint: String? = nil,
        confirm: Bool = true,
        action: @escaping () -> Void
    ) {
        self.accessibilityLabel = "Delete \(noun)"
        self.accessibilityHint = accessibilityHint
        self.confirmationTitle = confirm ? "Delete \(noun)" : nil
        self.confirmationMessage = confirm
            ? "Are you sure you want to delete this \(noun)?" + (extra.isEmpty ? "" : " " + extra)
            : nil
        self.action = action
    }

    public init(
        accessibilityLabel: String = "Delete",
        accessibilityHint: String? = nil,
        confirmationTitle: String? = nil,
        confirmationMessage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.confirmationTitle = confirmationTitle
        self.confirmationMessage = confirmationMessage
        self.action = action
    }

    public var body: some View {
        SBJImageButton(
            SBJSymbology.delete,
            role: .destructive,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint
        ) {
            if confirmationTitle == nil {
                action()
            } else {
                showingConfirmation = true
            }
        }
        .alert(confirmationTitle ?? accessibilityLabel, isPresented: $showingConfirmation) {
            Button("Delete", role: .destructive, action: action)
            Button("Cancel", role: .cancel) {}
        } message: {
            if let confirmationMessage {
                Text(confirmationMessage)
            }
        }
    }
}
