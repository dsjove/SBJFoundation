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
