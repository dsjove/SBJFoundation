import Foundation

extension String {
    /// Expands literal help tokens in one pass.
    ///
    /// Longer overlapping token names take precedence. Identifier-like tokens
    /// are matched as complete names, not as substrings of other identifiers.
    /// Replacement values are
    /// inserted verbatim, not recursively expanded, so URLs, embedded HTML and
    /// other replacement values cannot be accidentally rewritten by a later key.
    func replacingOccurrences(using replacements: [String: String]) -> String {
        let keys = replacements.keys.filter { !$0.isEmpty }.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0 < $1
        }
        guard !keys.isEmpty else { return self }

        func isIdentifierCharacter(_ character: Character) -> Bool {
            character.isLetter || character.isNumber || character == "_"
        }

        func matchesCompleteToken(_ key: String, at position: String.Index) -> Bool {
            guard self[position...].hasPrefix(key) else { return false }
            let end = index(position, offsetBy: key.count)
            if let first = key.first, isIdentifierCharacter(first), position > startIndex,
               isIdentifierCharacter(self[index(before: position)]) { return false }
            if let last = key.last, isIdentifierCharacter(last), end < endIndex,
               isIdentifierCharacter(self[end]) { return false }
            return true
        }

        var result = String()
        var position = startIndex
        while position < endIndex {
            if let key = keys.first(where: { matchesCompleteToken($0, at: position) }),
               let value = replacements[key] {
                result.append(contentsOf: value)
                position = index(position, offsetBy: key.count)
            } else {
                result.append(self[position])
                formIndex(after: &position)
            }
        }
        return result
    }
}
