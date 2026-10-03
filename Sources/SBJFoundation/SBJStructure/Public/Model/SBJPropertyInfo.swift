import Foundation

/// Supplemental documentation and accessibility information about a model property.
///
/// This metadata is intentionally UI-independent. Editors and other consumers may
/// choose how to present it.
public struct SBJPropertyInfo: Sendable, Equatable, Accessible {
    public let title: String?
    public let summary: String
    public let details: String
    public let accessibilityLabel: String?
    public let accessibilityHint: String?
    public let accessibilityValue: String?

    public init(
        title: String? = nil,
        summary: String,
        details: String,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        accessibilityValue: String? = nil
    ) {
        self.title = title
        self.summary = summary
        self.details = details
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.accessibilityValue = accessibilityValue
    }
}
