import Foundation

/// Declaration-site nomenclature and accessibility metadata.
/// Runtime accessibility values belong to SBJTextPresentable, not to this descriptor.
public struct SBJNomenclature: Sendable, Equatable {
    public let title: String
    public let summary: String?
    /// Canonical longer explanation, including instructions where appropriate.
    public let details: String?
    /// Alternative user-facing terms used to discover this property.
    /// These are semantic vocabulary, not accessibility overrides.
    public let aliases: [String]
    public let symbol: SBJSymbol?
    public let accessibilityLabel: String?
    public let accessibilityHint: String?

    public init(
        title: String = "",
        summary: String? = nil,
        details: String? = nil,
        aliases: [String] = [],
        symbol: SBJSymbol? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.title = title
        self.summary = summary
        self.details = details
        self.aliases = aliases
        self.symbol = symbol
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    /// Returns nil when no title was supplied. Empty titles are valid for standalone metadata.
    public var nonEmptyTitle: String? { title.isEmpty ? nil : title }

    /// Resolved declaration-site accessibility: explicit overrides, then title and summary.
    /// `details` is intentionally not used as an accessibility hint.
    public var accessibility: AccessibleItem {
        AccessibleItem(label: accessibilityLabel ?? nonEmptyTitle, hint: accessibilityHint ?? summary)
    }
}
