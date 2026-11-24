import Foundation

/// Explicit presentation ordering. The returned array is independent of the source set.
public extension Set where Element: Comparable {
    func sortedForPresentation(direction: SBJSortDirection) -> [Element] {
        switch direction {
        case .ascending: return sorted(by: <)
        case .descending: return sorted(by: >)
        }
    }
}

/// Explicit presentation ordering by key. No dictionary mutation occurs.
public extension Dictionary where Key: Comparable {
    func sortedForPresentation(direction: SBJSortDirection) -> [Element] {
        switch direction {
        case .ascending: return sorted { $0.key < $1.key }
        case .descending: return sorted { $0.key > $1.key }
        }
    }
}

/// Explicit presentation ordering by value, with a deterministic key tie-breaker.
public extension Dictionary where Key: Comparable, Value: Comparable {
    func sortedForPresentation(
        direction: SBJSortDirection,
        by target: SBJDictionarySortBy
    ) -> [Element] {
        switch target {
        case .key: return sortedForPresentation(direction: direction)
        case .value:
            switch direction {
            case .ascending:
                return sorted { lhs, rhs in
                    if lhs.value == rhs.value { return lhs.key < rhs.key }
                    return lhs.value < rhs.value
                }
            case .descending:
                return sorted { lhs, rhs in
                    if lhs.value == rhs.value { return lhs.key > rhs.key }
                    return lhs.value > rhs.value
                }
            }
        }
    }
}
