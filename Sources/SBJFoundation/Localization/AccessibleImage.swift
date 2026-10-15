import Foundation
import SBJSubject

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
    public let accessibilityLabel: String?
    public let accessibilityHint: String?
    public let accessibilityValue: String?

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
        self.accessibilityLabel = labeled ? label : nil
        self.accessibilityHint = hint
        self.accessibilityValue = value
    }
}

public extension StringPresentable where Self: RawRepresentable, Self.RawValue == String {
	nonisolated var description: String { rawValue.uncamelCased }
}

public extension Sequence where Element == String {
	/// Nonempty values joined as a compact presentation list.
	var presentationList: String {
		filter(\.hasContent).joined(separator: ", ")
	}

	/// Nonempty note strings joined using note punctuation.
	var presentationNotes: String {
		filter(\.hasContent).joined(separator: "; ")
	}
}

public extension Sequence where Element: StringPresentable {
	/// Nonempty values joined as a compact presentation list.
	var presentationList: String {
		map(\.description).filter(\.hasContent).joined(separator: ", ")
	}
}
