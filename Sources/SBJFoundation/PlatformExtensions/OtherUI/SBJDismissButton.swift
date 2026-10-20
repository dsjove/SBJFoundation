import SwiftUI
import SBJDataDefinition
import SBJLocalization

@MainActor
public struct SBJDismissButton: View {
    private let accessibilityLabel: String
    private let accessibilityHint: String?
    private let action: () -> Void

    /// TODO(Localization): `Dismiss` is framework-owned vocabulary and should move
    /// through the shared SBJ text-resource/catalog path when that design is
    /// implemented. See Documentation/LOCALIZATION_AND_PRESENTATION_RESOURCES.md.
    public init(
        accessibilityLabel: String = "Dismiss",
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    public var body: some View {
        SBJSymbolButton(
            SBJSymbology.dismiss,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint,
            action: action
        )
    }
}
