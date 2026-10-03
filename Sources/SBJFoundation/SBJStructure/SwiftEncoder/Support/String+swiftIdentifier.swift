import Foundation

/// Converts arbitrary text into a valid Swift identifier suitable for generated source.
public extension String {
	var swiftIdentifier: String {
		let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))

		let parts = self.split(whereSeparator: { $0.isWhitespace })

		var result = parts.enumerated()
			.map { index, part in
				let cleaned = part.unicodeScalars
					.map { allowed.contains($0) ? String($0) : "_" }
					.joined()

				guard index > 0, let first = cleaned.first else {
					return cleaned
				}

				return first.uppercased() + cleaned.dropFirst()
			}
			.joined()

		if result.isEmpty {
			result = "character"
		}

		if let first = result.unicodeScalars.first,
		   CharacterSet.decimalDigits.contains(first) {
			result = "_" + result
		}

		let keywords: Set<String> = [
			"class", "struct", "enum", "protocol", "extension", "func", "var", "let",
			"import", "return", "switch", "case", "default", "if", "else", "for", "while",
			"do", "catch", "throw", "throws", "try", "in", "where", "as", "is", "nil",
			"true", "false", "self", "Self", "super"
		]

		if keywords.contains(result) {
			result = "_" + result
		}

		return result
	}

	var isValidCVariableName: Bool {
		let regex = "^[a-zA-Z_][a-zA-Z0-9_]*$"
		return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: self)
	}

	var sanitizeCVariableName: String {
		let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmed.isValidCVariableName {
			return trimmed
		}

		var sanitizedName = ""
		if let first = self.first, String(first).range(of: "^[a-zA-Z_]$", options: .regularExpression) != nil {
			sanitizedName.append(first)
		}
		else {
			sanitizedName.append("_") // Default to '_' if invalid first character
		}
		let validSubsequentRegex = "[a-zA-Z0-9_]"
		for char in self.dropFirst() {
			if String(char).range(of: validSubsequentRegex, options: .regularExpression) != nil {
				sanitizedName.append(char)
			}
			else {
				sanitizedName.append("_")
			}
		}
		return sanitizedName
	}

	var uncamelCased: String {
		guard !isEmpty else { return self }
		let characters = Array(self)
		var result = ""
		result.reserveCapacity(characters.count + characters.count / 4)

		for index in characters.indices {
			let character = characters[index]
			if character == "_" {
				if result.last != " " { result.append(" ") }
				continue
			}
			if index > characters.startIndex {
				let previous = characters[index - 1]
				let next = index + 1 < characters.endIndex ? characters[index + 1] : nil
				let previousWasSeparator = previous == "_"
				let startsNewWord = character.isUppercase && !previousWasSeparator && (
					previous.isLowercase || previous.isNumber ||
					(previous.isUppercase && next?.isLowercase == true)
				)
				if startsNewWord, result.last != " " { result.append(" ") }
			}
			result.append(character)
		}
		return result.prefix(1).uppercased() + result.dropFirst()
	}
}
