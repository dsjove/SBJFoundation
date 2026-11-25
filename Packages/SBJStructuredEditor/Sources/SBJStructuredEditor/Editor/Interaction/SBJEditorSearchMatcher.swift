import SBJStructure
#if !os(tvOS) && !os(watchOS)
/// Apply the editor's property visibility policy when recursively matching text.
/// Leaf matching and normalization remain owned by SBJStructure.
enum SBJEditorSearchMatcher {
    static func matches(
        label: String, value: Any, query: String, showsReadOnlyProperties: Bool
    ) -> Bool {
        if showsReadOnlyProperties {
            return sbjPredicated(label: label, value: value, search: query)
        }
        return sbjPredicated(label, search: query) || matchesWritableContent(value, query: query, depth: 0)
    }

    private static func matchesStructured<Root: SBJStructured>(
        _ root: Root, query: String, depth: Int
    ) -> Bool {
        Root.sbjUserFacingProperties.contains { property in
            guard property.access == .readWrite else { return false }
            return sbjPredicated(property.displayName, search: query)
                || sbjPredicated(property.sourceName, search: query)
                || matchesWritableContent(property.value(in: root), query: query, depth: depth + 1)
        }
    }

    private static func matchesWritableContent(_ value: Any, query: String, depth: Int) -> Bool {
        // Keep the same recursion bound and atomic boundary as structural search.
        guard depth < 64 else { return false }
        if value is any SBJStructuralSearchAtomic {
            return sbjPredicated(value, search: query)
        }
        if let structured = value as? any SBJStructured {
            return matchesStructured(structured, query: query, depth: depth)
        }
        if let associated = value as? any SBJStructuredEnum {
            return sbjPredicated(associated.sbjCaseName, search: query)
                || associated.sbjStructuralAssociatedChildren().dropFirst().contains { child in
                    sbjPredicated(child.title, search: query)
                        || matchesWritableContent(child.value, query: query, depth: depth + 1)
                }
        }
        if let container = value as? any SBJStructuralValueContainer {
            return container.sbjStructuralChildren(itemTitleKey: nil, itemIdentifierKey: nil).contains { child in
                if let key = child.dictionaryKey,
                   matchesWritableContent(key, query: query, depth: depth + 1) { return true }
                return matchesWritableContent(child.value, query: query, depth: depth + 1)
            }
        }
        return sbjPredicated(value, search: query)
    }
}
#endif
