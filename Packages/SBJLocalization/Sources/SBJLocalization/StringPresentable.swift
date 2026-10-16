import Foundation

/// Legacy presentation contract to be folded into SBJStructure's localization/text
/// resolution design. `description`, `abbreviation`, and `multiLineDescription`
/// are distinct presentation candidates, not merely formatting conveniences;
/// preserve that distinction when the shared text model is introduced.
///
/// See the Character package’s `Documentation/StringPresentableAudit.md` for
/// migration notes; review that document against current implementations.
///
/// TODO(Localization): replace this protocol only after the shared SBJ text
/// representation can express localized/default text, compact alternatives,
/// formatted/domain values, verbatim output, and renderer-selected fit candidates.
/// The default `multiLineDescription` below is legacy layout behavior, not a
/// promise that mechanically inserted newlines are a distinct localized resource.
public protocol StringPresentable {
	var description: String { get }
	var abbreviation: String { get }
	var multiLineDescription: String { get }
}

public extension StringPresentable {
	var abbreviation: String {
		description
	}

	var multiLineDescription: String {
		description.replacingOccurrences(of: " ", with: "\n")
	}
}

public extension StringPresentable where Self: RawRepresentable, Self.RawValue == String {
	nonisolated var description: String { rawValue.uncamelCased }
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

public extension Sequence where Element: StringPresentable {
	/// Nonempty values joined as a compact presentation list.
	var presentationList: String {
		map(\.description).filter { !$0.isEmpty }.joined(separator: ", ")
	}
}
