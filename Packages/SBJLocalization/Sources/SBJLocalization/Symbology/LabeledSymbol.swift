import Foundation

/// Semantic image and optional textual/accessibility metadata.
/// Presentation (including `.labelStyle`) belongs to the call site.
public struct LabeledSymbol: Sendable {
    public let symbol: SBJSymbol
    public let title: String?
    public let accessibilityLabel: String?
    public let accessibilityHint: String?

    public init(
        symbol: SBJSymbol,
        title: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.symbol = symbol
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }
}
