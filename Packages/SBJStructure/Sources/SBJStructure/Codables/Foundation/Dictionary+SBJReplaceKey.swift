import Foundation

public extension Dictionary {
    /// Rename an existing key without overwriting another entry. The original
    /// value, including a present nil optional value, is retained unchanged.
    @discardableResult
    mutating func sbjReplaceKey(_ oldKey: Key, with newKey: Key) -> Bool {
        guard let oldIndex = index(forKey: oldKey) else { return false }
        if oldKey == newKey { return true }
        guard index(forKey: newKey) == nil else { return false }
        let member = self[oldIndex].value
        remove(at: oldIndex)
        updateValue(member, forKey: newKey)
        return true
    }
}
