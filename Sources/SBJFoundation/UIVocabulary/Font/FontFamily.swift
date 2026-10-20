import Foundation

/// A normalized font-family name. A nil `FontFamily?` represents the system font.
public struct FontFamily: Hashable, Sendable, Codable, ExpressibleByStringLiteral,
	CustomStringConvertible, CustomDebugStringConvertible {
	public let name: String

	/// Removes surrounding whitespace and applies Unicode canonical composition.
	/// The original case is retained for display and font-family lookup.
	public init(_ name: String) {
		self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
			.precomposedStringWithCanonicalMapping
	}

	public init(stringLiteral value: String) {
		self.init(value)
	}

	public var description: String { name }
	public var debugDescription: String { name.debugDescription }
}
