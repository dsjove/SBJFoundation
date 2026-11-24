/// Inspection only: no sorting, repair, or mutation is performed.
public extension Array where Element: Comparable {
    /// The first index whose element violates the requested adjacent ordering.
    /// Equal neighboring values are accepted in either direction.
    func firstOutOfOrderIndex(direction: SBJSortDirection) -> Int? {
        guard count > 1 else { return nil }
        for index in 1..<count {
            switch direction {
            case .ascending where self[index] < self[index - 1]: return index
            case .descending where self[index - 1] < self[index]: return index
            default: break
            }
        }
        return nil
    }
}
