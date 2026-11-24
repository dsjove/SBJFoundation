import SwiftUI

//TODO: rectify with SBJDeleteButton

@MainActor
public struct SBJRemoveButton: View {
    private let accessibilityLabel: String
    private let accessibilityHint: String?
    private let action: () -> Void

    public init(
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.accessibilityLabel = accessibilityLabel ?? SBJCommonNomenclature.remove.title
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    public var body: some View {
        SBJSymbolButton(
            SBJCommonNomenclature.remove.symbol!,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint,
            action: action
        )
    }
}
