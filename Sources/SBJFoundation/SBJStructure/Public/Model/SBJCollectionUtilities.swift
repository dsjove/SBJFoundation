import Foundation

/// UI-independent helpers for deriving stable, human-readable identities for
/// collection elements.
///
/// `itemTitleKey` corresponds to the property name recorded by the structural
/// `.itemTitle` metadata hint. Consumers such as editors, diagnostics, loggers,
/// and exporters can use the same naming rules without depending on SwiftUI.
public enum SBJCollectionItemIdentification {
    /// Returns the configured item title when available, otherwise a readable
    /// description of the element itself.
    public static func title<Element>(for element: Element, itemTitleKey: String? = nil) -> String {
        configuredTitle(for: element, itemTitleKey: itemTitleKey)
            ?? displayTitle(element)
            ?? String(describing: element)
    }

    /// Returns a title derived specifically from the configured `.itemTitle`
    /// property, or `nil` when no key is configured or that property has no
    /// usable value.
    public static func configuredTitle<Element>(
        for element: Element,
        itemTitleKey: String?
    ) -> String? {
        guard let itemTitleKey,
              let raw = propertyValue(named: itemTitleKey, in: element),
              let title = displayTitle(raw),
              !title.isEmpty else {
            return nil
        }
        return title
    }

    /// Returns an array element title suitable for a structural path. Arrays
    /// have an intrinsic position, so the index is used when no configured
    /// item title can be derived.
    public static func arrayTitle<Element>(
        for element: Element,
        index: Int,
        itemTitleKey: String? = nil
    ) -> String {
        configuredTitle(for: element, itemTitleKey: itemTitleKey) ?? "[\(index)]"
    }

    /// Stable string token for a configured collection item identifier property.
    /// The key is normally supplied by `@SBJArray(uniqueBy:)`.
    public static func stableIdentifier<Element>(
        for element: Element,
        itemIdentifierKey: String?
    ) -> String? {
        guard let itemIdentifierKey,
              let raw = propertyValue(named: itemIdentifierKey, in: element) else { return nil }
        return "\(String(reflecting: type(of: raw))):\(String(reflecting: raw))"
    }

    private static func propertyValue(named key: String, in value: Any) -> Any? {
        var mirror: Mirror? = Mirror(reflecting: value)
        while let current = mirror {
            for child in current.children where child.label == key {
                return child.value
            }
            mirror = current.superclassMirror
        }
        return nil
    }

    private static func displayTitle(_ value: Any) -> String? {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let child = mirror.children.first else { return nil }
            return displayTitle(child.value)
        }
        if let string = value as? String { return string }
        return String(describing: value).uncamelCased
    }
}

/// Deterministic ordering for otherwise unordered collections.
///
/// This is intended for stable traversal and output (diagnostics, logging,
/// snapshots, editors, etc.), not as a replacement for a model's semantic
/// ordering. Natural scalar values are compared by value; other values use
/// their structural display title with a reflected-description tie breaker.
public enum SBJCollectionOrdering {
    public static func sorted<Element: Hashable>(_ values: Set<Element>) -> [Element] {
        values.sorted { lhs, rhs in
            compare(lhs, rhs)
        }
    }

    public static func sortedEntries<Key: Hashable, Value>(
        _ values: [Key: Value]
    ) -> [(key: Key, value: Value)] {
        values.sorted { lhs, rhs in
            compare(lhs.key, rhs.key)
        }
    }

    private static func compare<T>(_ lhs: T, _ rhs: T) -> Bool {
        switch (lhs, rhs) {
        case let (lhs as String, rhs as String): return lhs.localizedStandardCompare(rhs) == .orderedAscending
        case let (lhs as Int, rhs as Int): return lhs < rhs
        case let (lhs as Int8, rhs as Int8): return lhs < rhs
        case let (lhs as Int16, rhs as Int16): return lhs < rhs
        case let (lhs as Int32, rhs as Int32): return lhs < rhs
        case let (lhs as Int64, rhs as Int64): return lhs < rhs
        case let (lhs as UInt, rhs as UInt): return lhs < rhs
        case let (lhs as UInt8, rhs as UInt8): return lhs < rhs
        case let (lhs as UInt16, rhs as UInt16): return lhs < rhs
        case let (lhs as UInt32, rhs as UInt32): return lhs < rhs
        case let (lhs as UInt64, rhs as UInt64): return lhs < rhs
        case let (lhs as Double, rhs as Double): return lhs < rhs
        case let (lhs as Float, rhs as Float): return lhs < rhs
        default:
            let left = SBJCollectionItemIdentification.title(for: lhs)
            let right = SBJCollectionItemIdentification.title(for: rhs)
            let result = left.localizedStandardCompare(right)
            if result != .orderedSame { return result == .orderedAscending }
            return String(reflecting: lhs) < String(reflecting: rhs)
        }
    }
}
