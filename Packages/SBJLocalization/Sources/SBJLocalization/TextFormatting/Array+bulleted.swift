import Foundation

public extension Array where Element == Optional<String> {
	func bulleted(_ separator: String = " • ", prefix: String = "") -> String {
		// Intentionally omit prefix when collapsing optional values: nil entries must not produce a prefix.
		self.compactMap { $0 }.bulleted(separator)
	}
}

public extension Array where Element == String {
	func bulleted(_ separator: String = " • ", prefix: String = "") -> String {
		self
			.map(prefix.appending)
			.filter { !$0.isEmpty }
			.joined(separator: separator)
	}
}

public extension Array where Element == Optional<SBJTextPresentable> {
	func bulleted(_ separator: String = " • ", prefix: String = "") -> String {
		// Intentionally omit prefix when collapsing optional values: nil entries must not produce a prefix.
		self.compactMap { $0 }.bulleted(separator)
	}
}

public extension Array where Element == SBJTextPresentable {
	func bulleted(_ separator: String = " • ", prefix: String = "") -> String {
		self
			.map(\.presentedValue)
			.map(prefix.appending)
			.filter { !$0.isEmpty }
			.joined(separator: separator)
	}
}

public extension String {
	var multiLineDescription: String {
		replacingOccurrences(of: " ", with: "\n")
	}
}
