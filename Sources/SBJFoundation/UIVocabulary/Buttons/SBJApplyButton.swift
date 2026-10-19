import SwiftUI
import SBJDataDefinition
import SBJLocalization

@MainActor
public struct SBJApplyButton: View {
    private let accessibilityLabel: String
    private let action: () -> Void

    public init(accessibilityLabel: String = "Apply", action: @escaping () -> Void) {
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        SBJImageButton(
            SBJSymbology.apply,
            accessibilityLabel: accessibilityLabel,
            action: action
        )
    }
}
