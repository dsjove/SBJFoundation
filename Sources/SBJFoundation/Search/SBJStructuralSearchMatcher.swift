import Foundation

/// One normalized query reused throughout a structural match.  In particular,
/// this avoids repeatedly allocating a full `String(describing:)` representation
/// for large structs/collections at every ancestor in the editor tree.
private struct SBJStructuralSearchMatcher {
    let originalQuery: String
    let normalizedQuery: String

    init?(_ search: String) {
        guard let query = search.querify else { return nil }
        let normalized = query.normalizedSearchText
        guard !normalized.isEmpty else { return nil }
        self.originalQuery = query
        self.normalizedQuery = normalized
    }

    func matchesText(_ text: String) -> Bool {
        text.normalizedSearchText.contains(normalizedQuery)
    }

    func matches(_ value: Any, depth: Int = 0) -> Bool {
        // Codable values should not form cycles in normal SBJStructure use, but
        // keep malformed/reflected object graphs from recursing without bound.
        guard depth < 64 else { return false }

        if let predicated = value as? any Predicated {
            return predicated.predicated(search: originalQuery)
        }

        if let searchable = value as? any SearchProtocol,
           matchesText(searchable.text) {
            return true
        }

        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let child = mirror.children.first else { return false }
            return matches(child.value, depth: depth + 1)
        }

        // Search-leaf types own this boundary. The matcher depends on the
        // capability rather than maintaining knowledge of concrete value types.
        if value is any SBJStructuralSearchLeaf {
            if let description = SBJValueDescription.describe(value) {
                return matchesText(description)
            }
            return matchesText(String(describing: value))
        }

        if (mirror.displayStyle == .struct || mirror.displayStyle == .class),
           let described = value as? any CustomStringConvertible {
            let text = described.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty, matchesText(text) { return true }
        }

        switch mirror.displayStyle {
        case .struct, .class, .collection, .set, .dictionary, .tuple:
            for child in mirror.children {
                if let label = child.label, matchesText(label) { return true }
                if matches(child.value, depth: depth + 1) { return true }
            }
            return false

        case .enum:
            // Associated-value enums expose their payload through Mirror. Search
            // the case/child label first and then each associated value instead
            // of stringifying the complete payload recursively.
            if mirror.children.isEmpty {
                return matchesText(String(describing: value))
            }
            for child in mirror.children {
                if let label = child.label, matchesText(label) { return true }
                if matches(child.value, depth: depth + 1) { return true }
            }
            return false

        default:
            if let description = SBJValueDescription.describe(value) {
                return matchesText(description)
            }
            return matchesText(String(describing: value))
        }
    }


}

// MARK: - Internal structural/editor matching

/// Matches display text using the same normalized semantics as the public
/// String/Predicated API.
func sbjPredicated(_ text: String, search: String) -> Bool {
    guard let matcher = SBJStructuralSearchMatcher(search) else { return true }
    return matcher.matchesText(text)
}

/// Matches an arbitrary value for structural/editor search without first
/// constructing a recursive textual description of the entire value.
func sbjPredicated<Value>(_ value: Value, search: String) -> Bool {
    guard let matcher = SBJStructuralSearchMatcher(search) else { return true }
    return matcher.matches(value)
}

func sbjPredicated<Value>(label: String, value: Value, search: String) -> Bool {
    guard let matcher = SBJStructuralSearchMatcher(search) else { return true }
    return matcher.matchesText(label) || matcher.matches(value)
}
