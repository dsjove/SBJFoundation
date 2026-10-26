import Foundation

/// Compile-time declaration-site documentation and accessibility metadata.
/// Runtime accessibility values belong to SBJTextPresentable, not to this descriptor.
public struct SBJPropertyInfo: Sendable, Equatable {
    public let title: String?
    public let summary: String?
    public let details: String?
    public let symbol: SBJSymbol?
    public let accessibilityLabel: String?
    public let accessibilityHint: String?

    public init(
        title: String? = nil,
        summary: String? = nil,
        details: String? = nil,
        symbol: SBJSymbol? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.title = title
        self.summary = summary
        self.details = details
        self.symbol = symbol
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    /// Declaration-site accessibility metadata only.
    public var accessibility: AccessibleItem {
        AccessibleItem(label: accessibilityLabel, hint: accessibilityHint)
    }
}
