import Foundation
import SBJSubject

public extension Array where Element == Optional<String> {
	func bulleted(_ separator: String = " • ", prefix: String = "") -> String {
		self.compactMap { $0 }.bulleted(separator)
	}
}

public extension Array where Element == String {
	func bulleted(_ separator: String = " • ", prefix: String = "") -> String {
		self
			.map(prefix.appending)
			.filter(\.hasContent)
			.joined(separator: separator)
	}
}

public extension Array where Element == Optional<StringPresentable> {
	func bulleted(_ separator: String = " • ", prefix: String = "") -> String {
		self.compactMap { $0 }.bulleted(separator)
	}
}

public extension Array where Element == StringPresentable {
	func bulleted(_ separator: String = " • ", prefix: String = "") -> String {
		self
			.map(\.description)
			.map(prefix.appending)
			.filter(\.hasContent)
			.joined(separator: separator)
	}
}

public extension String {
	var multiLineDescription: String {
		replacingOccurrences(of: " ", with: "\n")
	}
}
