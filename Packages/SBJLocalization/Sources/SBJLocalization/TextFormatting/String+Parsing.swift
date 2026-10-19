import Foundation

public extension String {
	func splitAndTrim(separator s: String = ",") -> [String] {
		components(separatedBy: s)
			.map { $0.trimmingCharacters(in: .whitespaces) }
	}

	func limitingExplicitLines(to maxLines: Int?) -> String {
		guard
			let maxLines,
			maxLines > 0,
			maxLines != Int.max
		else {
			return self
		}
		var lineCount = 1
		for index in indices {
			guard self[index] == "\n" else {
				continue
			}
			if lineCount == maxLines {
				return String(self[..<index])
			}
			lineCount += 1
		}
		return self
	}
}

public extension Int {
	func signedDescription(apply: Bool = true, zero: Bool = true) -> String {
		if apply && ((zero && self == 0) || (self > 0)) {
			"+\(self)"
		} else {
			"\(self)"
		}
	}
}

