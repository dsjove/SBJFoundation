import SwiftUI

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
        self.accessibilityLabel = accessibilityLabel ?? (direction == .up ? SBJCommonNomenclature.moveUp.title : SBJCommonNomenclature.moveDown.title)
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    public var body: some View {
        SBJSymbolButton(
            direction == .up ? SBJCommonNomenclature.moveUp.symbol! : SBJCommonNomenclature.moveDown.symbol!,
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
