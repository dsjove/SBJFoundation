import Foundation

/// Supplemental documentation and accessibility information about a model property.
///
/// This metadata is intentionally UI-independent. Editors and other consumers may
/// choose how to present it.
public struct SBJPropertyInfo: Sendable, Equatable, Accessible {
    public let title: String?
    public let summary: String?
    public let details: String?
    public let symbol: SBJSymbol?
    public let accessibility: AccessibleItem

    public var accessibilityLabel: String? { accessibility.accessibilityLabel }
    public var accessibilityHint: String? { accessibility.accessibilityHint }
    public var accessibilityValue: String? { accessibility.accessibilityValue }

    public init(
        title: String? = nil,
        summary: String? = nil,
        details: String? = nil,
        symbol: SBJSymbol? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        accessibilityValue: String? = nil
    ) {
        self.title = title
        self.summary = summary
        self.details = details
        self.symbol = symbol
        self.accessibility = AccessibleItem(label: accessibilityLabel, hint: accessibilityHint, value: accessibilityValue)
    }

    /// Explicit metadata initializer for callers that already have accessibility semantics.
    public init(
		title: String? = nil,
		summary: String? = nil,
		details: String? = nil,
		symbol: SBJSymbol? = nil,
		accessibility: AccessibleItem
	) {
        self.title = title
        self.summary = summary
        self.details = details
        self.symbol = symbol
        self.accessibility = accessibility
    }
}
