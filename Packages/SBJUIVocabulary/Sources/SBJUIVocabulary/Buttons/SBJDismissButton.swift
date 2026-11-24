import SwiftUI

/// Compact action to dismiss or close a presented view.
@MainActor
public struct SBJDismissButton: View {
	private let accessibilityLabel: String
	private let accessibilityHint: String?
	@Environment(\.dismiss) private var dismiss
	private let action: (() -> Void)?

	public init(
		accessibilityLabel: String? = nil,
		accessibilityHint: String? = nil,
		action: (() -> Void)? = nil
	) {
		self.accessibilityLabel = accessibilityLabel ?? SBJCommonNomenclature.dismiss.title
		self.accessibilityHint = accessibilityHint
		self.action = action
	}

	public var body: some View {
		SBJSymbolButton(
			SBJCommonNomenclature.dismiss.symbol!,
			accessibilityLabel: accessibilityLabel,
			accessibilityHint: accessibilityHint,
			action: {
				if let action { action() } else { dismiss() }
			}
		)
	}
}
