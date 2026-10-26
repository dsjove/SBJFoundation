import Foundation

/// Text presentation independent of accessibility.
/// A future localized-text representation can replace these display candidates.
public protocol SBJTextPresentable {
	var presentedValue: String { get }
	var accessibilityValue: String? { get }
	var abbreviation: String { get }
	var multiLineDescription: String { get }
}

public extension SBJTextPresentable {
    var accessibilityValue: String? { nil }

	var abbreviation: String {
		presentedValue
	}

	var multiLineDescription: String {
		presentedValue.replacingOccurrences(of: " ", with: "\n")
	}
}

public extension SBJTextPresentable where Self: RawRepresentable, Self.RawValue == String {
	nonisolated var presentedValue: String { rawValue.uncamelCased }
}

public extension Sequence where Element == String {
	/// Nonempty values joined as a compact presentation list.
	var presentationList: String {
		filter { !$0.isEmpty }.joined(separator: ", ")
	}

	/// Nonempty note strings joined using note punctuation.
	var presentationNotes: String {
		filter { !$0.isEmpty }.joined(separator: "; ")
	}
}

public extension Sequence where Element: SBJTextPresentable {
	/// Nonempty values joined as a compact presentation list.
	var presentationList: String {
		map(\.presentedValue).filter { !$0.isEmpty }.joined(separator: ", ")
	}
}
