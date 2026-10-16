import Foundation
import SBJLocalization

/// An image reference with optional visible and spoken descriptions.
public protocol AccessibleImage: Accessible {
    var image: ImageReference { get }
    var labeled: Bool { get }
    var label: String { get }
}

public extension AccessibleImage {
    var labeled: Bool { false }
}

/// Image metadata that supplies a spoken label when its visible label is enabled.
public struct AccessibleImageItem: AccessibleImage {
    public let image: ImageReference
    public let labeled: Bool
    public let label: String
    public let accessibility: AccessibleItem

    public var accessibilityLabel: String? { accessibility.accessibilityLabel }
    public var accessibilityHint: String? { accessibility.accessibilityHint }
    public var accessibilityValue: String? { accessibility.accessibilityValue }

    public init(
        image: ImageReference,
        labeled: Bool = false,
        label: String,
        hint: String? = nil,
        value: String? = nil
    ) {
        self.image = image
        self.labeled = labeled
        self.label = label
        self.accessibility = AccessibleItem(label: labeled ? label : nil, hint: hint, value: value)
    }
}
