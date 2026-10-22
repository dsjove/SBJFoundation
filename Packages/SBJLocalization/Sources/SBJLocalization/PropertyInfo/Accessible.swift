import Foundation

/// Accessibility semantics that can be attached to a model, descriptor, or UI item.
///
/// This is intentionally presentation-independent. SwiftUI support is supplied by
/// the `View.accessibility(_:)` adapter in `Localization`.
public protocol Accessible {
    /// A concise name identifying the accessible element, independent of its current value.
    var accessibilityLabel: String? { get }

    /// Additional guidance about the element or the result of activating it.
    var accessibilityHint: String? { get }

    /// The element's current state or value, distinct from its label.
    var accessibilityValue: String? { get }
}

public extension Accessible {
    var accessibilityLabel: String? { nil }
    var accessibilityHint: String? { nil }
    var accessibilityValue: String? { nil }
}

//TODO: Delete?
/// Concrete accessibility metadata for labels, hints, and values.
public struct AccessibleItem: Accessible, Sendable, Equatable, Hashable {
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
