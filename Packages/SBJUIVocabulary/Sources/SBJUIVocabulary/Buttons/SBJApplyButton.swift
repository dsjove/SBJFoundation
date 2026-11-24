import SwiftUI

@MainActor
public struct SBJApplyButton: View {
    private let accessibilityLabel: String
    private let action: () -> Void

    public init(accessibilityLabel: String? = nil, action: @escaping () -> Void) {
        self.accessibilityLabel = accessibilityLabel ?? SBJCommonNomenclature.apply.title
        self.action = action
    }

    public var body: some View {
        SBJSymbolButton(
            SBJCommonNomenclature.apply.symbol!,
            accessibilityLabel: accessibilityLabel,
            action: action
        )
    }
}
