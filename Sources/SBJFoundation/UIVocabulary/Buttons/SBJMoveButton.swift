import SwiftUI
import SBJDataDefinition
import SBJLocalization

// TODO: editor only?
@MainActor
public struct SBJMoveButton: View {
    public let direction: SBJMoveDirection
    private let accessibilityLabel: String
    private let accessibilityHint: String?
    private let action: (() -> Void)?

    public init(
        _ direction: SBJMoveDirection,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        action: (() -> Void)?
    ) {
        self.direction = direction
        self.accessibilityLabel = accessibilityLabel ?? (direction == .up ? "Move up" : "Move down")
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    public var body: some View {
        SBJSymbolButton(
            direction == .up ? SBJSymbology.moveUp : SBJSymbology.moveDown,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint
        ) {
            action?()
        }
        .disabled(action == nil)
    }
}

public enum SBJMoveDirection: Sendable {
    case up
    case down
}
