import SwiftUI
import SBJDataDefinition
import SBJLocalization

@MainActor
public struct SBJMoveToButton: View {
    public let direction: SBJMoveToDirection
    private let accessibilityLabel: String
    private let accessibilityHint: String?
    private let action: (() -> Void)?

    public init(
        _ direction: SBJMoveToDirection,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        action: (() -> Void)?
    ) {
        self.direction = direction
        self.accessibilityLabel = accessibilityLabel ?? (direction == .first ? "Move to first" : "Move to last")
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    public var body: some View {
        SBJImageButton(
            direction == .first ? SBJSymbology.moveToFirst : SBJSymbology.moveToLast,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint
        ) {
            action?()
        }
        .disabled(action == nil)
    }
}

public enum SBJMoveToDirection: Sendable {
    case first
    case last
}
