import SwiftUI

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
        self.accessibilityLabel = accessibilityLabel ?? (direction == .first ? SBJCommonNomenclature.moveToFirst.title : SBJCommonNomenclature.moveToLast.title)
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    public var body: some View {
        SBJSymbolButton(
            direction == .first ? SBJCommonNomenclature.moveToFirst.symbol! : SBJCommonNomenclature.moveToLast.symbol!,
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
