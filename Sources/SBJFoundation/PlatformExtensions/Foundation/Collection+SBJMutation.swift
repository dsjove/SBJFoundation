import Foundation

import SBJDataDefinition
public extension Set {
    /// Replaces one element without silently collapsing the set when the
    /// replacement already exists.
    ///
    /// Returns `false` and leaves the set unchanged if `oldValue` is absent or
    /// `newValue` would collide with another existing member.
    @discardableResult
    mutating func sbjReplace(_ oldValue: Element, with newValue: Element) -> Bool {
        guard contains(oldValue) else { return false }
        if oldValue != newValue, contains(newValue) { return false }
        remove(oldValue)
        insert(newValue)
        return true
    }
}

public extension Dictionary {
    /// Renames a key without overwriting an existing entry.
    ///
    /// Returns `false` and leaves the dictionary unchanged if `oldKey` is
    /// absent or `newKey` already belongs to another entry.
    @discardableResult
    mutating func sbjRenameKey(_ oldKey: Key, to newKey: Key) -> Bool {
        guard let value = self[oldKey] else { return false }
        if oldKey != newKey, self[newKey] != nil { return false }
        removeValue(forKey: oldKey)
        updateValue(value, forKey: newKey)
        return true
    }
}

public extension Collection where Element: Hashable {
    /// Removes duplicate elements while retaining the first occurrence of each value.
    func removingDuplicatesPreservingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }

    /// Removes duplicate elements without preserving source order.
    func removingDuplicatesUnordered() -> [Element] {
        Array(Set(self))
    }

    /// Convenience wrapper around `Dictionary(grouping:by:)`.
    func grouped<Key: Hashable>(by keySelector: (Element) -> Key) -> [Key: [Element]] {
        Dictionary(grouping: self, by: keySelector)
    }
}

public extension Collection {
    var second: Element? {
        guard count > 1 else { return nil }
        return self[index(after: startIndex)]
    }
}
