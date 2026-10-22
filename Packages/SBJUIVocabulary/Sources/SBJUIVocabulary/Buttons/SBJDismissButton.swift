import SwiftUI
import SBJDataDefinition

/// Compact action to dismiss or close a presented view.
@MainActor
public struct SBJDismissButton: View {
	private let accessibilityLabel: String
	private let accessibilityHint: String?
	@Environment(\.dismiss) private var dismiss
	private let action: (() -> Void)?

	public init(
		accessibilityLabel: String = "Dismiss",
		accessibilityHint: String? = nil,
		action: (() -> Void)? = nil
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
			action: {
				if let action { action() } else { dismiss() }
			}
		)
	}
}
