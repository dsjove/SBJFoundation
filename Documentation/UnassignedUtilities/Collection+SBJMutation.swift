import Foundation

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

public extension Collection {
    var second: Element? {
        guard count > 1 else { return nil }
        return self[index(after: startIndex)]
    }
}
