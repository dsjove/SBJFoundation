import Foundation

/// Concrete accessibility metadata for labels, hints, and values.
public struct AccessibleItem: Sendable, Equatable, Hashable {
    public let accessibilityLabel: String?
    public let accessibilityHint: String?
    public let accessibilityValue: String?

    public init(
        label: String? = nil,
        hint: String? = nil,
        value: String? = nil
    ) {
        self.accessibilityLabel = label
        self.accessibilityHint = hint
        self.accessibilityValue = value
    }

    public var isEmpty: Bool {
        accessibilityLabel == nil && accessibilityHint == nil && accessibilityValue == nil
    }
}
