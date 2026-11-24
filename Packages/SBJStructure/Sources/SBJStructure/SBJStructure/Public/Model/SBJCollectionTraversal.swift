import Foundation

/// A model-only description of an element in a collection traversal.
/// The logical identifier and current location are separate: an element with a
/// unique model identifier can move without changing its logical identity.
public struct SBJCollectionTraversalElement<Element> {
    public let value: Element
    public let title: String
    public let identifier: String
    public let location: String
    public let index: Int?

    public init(value: Element, title: String, identifier: String, location: String, index: Int? = nil) {
        self.value = value
        self.title = title
        self.identifier = identifier
        self.location = location
        self.index = index
    }
}

/// Canonical, UI-independent collection traversal order and identity policy.
/// Consumers project these entries into editor rows, diagnostics, or visitors.
public enum SBJCollectionTraversal {
    public static func array<Element>(
        _ values: [Element], itemTitleKey: String? = nil, itemIdentifierKey: String? = nil
    ) -> [SBJCollectionTraversalElement<Element>] {
        values.enumerated().map { index, element in
            let configured = SBJCollectionItemIdentification.stableIdentifier(
                for: element, itemIdentifierKey: itemIdentifierKey
            )
            let unique: String? = {
                guard let configured, let itemIdentifierKey,
                      SBJCollectionItemIdentification.uniqueIndex(
                          in: values, identifier: configured, itemIdentifierKey: itemIdentifierKey
                      ) != nil else { return nil }
                return configured
            }()
            return .init(
                value: element,
                title: SBJCollectionItemIdentification.arrayTitle(for: element, index: index, itemTitleKey: itemTitleKey),
                identifier: "item:\(unique ?? "slot:\(index)")",
                location: "index:\(index)", index: index
            )
        }
    }

    /// Resolve the current position of a previously enumerated array element.
    ///
    /// Unique model identities are re-resolved after reorder or insertion. An
    /// element without a unique configured identity remains positional, matching
    /// the editor's established behavior. Callers performing deferred writes
    /// should separately reject positional references when their snapshots
    /// are stale.
    public static func currentIndex<Element>(
        of item: SBJCollectionTraversalElement<Element>,
        in values: [Element],
        itemIdentifierKey: String? = nil
    ) -> Int? {
        guard let originalIndex = item.index else { return nil }
        if item.identifier != "item:slot:\(originalIndex)",
           let itemIdentifierKey,
           let identifier = SBJCollectionItemIdentification.stableIdentifier(
               for: item.value, itemIdentifierKey: itemIdentifierKey
           ) {
            return SBJCollectionItemIdentification.uniqueIndex(
                in: values, identifier: identifier, itemIdentifierKey: itemIdentifierKey
            )
        }
        return values.indices.contains(originalIndex) ? originalIndex : nil
    }

    /// Whether a reference depends on array position rather than model identity.
    public static func isPositional<Element>(
        _ item: SBJCollectionTraversalElement<Element>
    ) -> Bool {
        guard let index = item.index else { return false }
        return item.identifier == "item:slot:\(index)"
    }

    public static func set<Element: Hashable>(
        _ values: Set<Element>, itemTitleKey: String? = nil
    ) -> [SBJCollectionTraversalElement<Element>] {
        SBJCollectionOrdering.sorted(values).map { element in
            let token = "item:\(String(reflecting: type(of: element))):\(String(reflecting: element))"
            return .init(value: element,
                         title: SBJCollectionItemIdentification.title(for: element, itemTitleKey: itemTitleKey),
                         identifier: token, location: token)
        }
    }

    public static func dictionary<Key: Hashable, Value>(
        _ values: [Key: Value]
    ) -> [SBJCollectionTraversalElement<(key: Key, value: Value)>] {
        SBJCollectionOrdering.sortedEntries(values).map { key, value in
            let token = "key:\(String(reflecting: key))"
            return .init(value: (key: key, value: value), title: String(describing: key),
                         identifier: token, location: token)
        }
    }
}
