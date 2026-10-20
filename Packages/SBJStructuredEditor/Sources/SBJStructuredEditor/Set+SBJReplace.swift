import Foundation

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
