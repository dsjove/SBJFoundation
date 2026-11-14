import Foundation

/// An ordered set expression over tags. Start with everything or nothing;
/// successive rules add or subtract users bearing the selected tag.
/// Stable identifiers allow unknown/deleted tags to remain visible to editors.
public struct TagFilter<Tag: Tagging>: Equatable where Tag.ID: Hashable {
    public struct Operation: Equatable {
        public var tagID: Tag.ID
        public var add: Bool

        public init(tagID: Tag.ID, add: Bool) {
            self.tagID = tagID
            self.add = add
        }
    }

    public var startAll: Bool
    public var operations: [Operation]

    public init(startAll: Bool = true, operations: [Operation] = []) {
        self.startAll = startAll
        self.operations = operations
    }

    public func matches(tagIDs: Set<Tag.ID>) -> Bool {
        var included = startAll
        for operation in operations where tagIDs.contains(operation.tagID) {
            included = operation.add
        }
        return included
    }

    /// A TagUser predicate using its existing SBJTags relationship API.
    /// Unresolved operations have no matching user but remain available to the UI.
    public func matches<User: TagUser>(_ user: User, availableTags: [Tag]) -> Bool where User.Tag == Tag {
        let assigned = Set(availableTags.filter { user.hasTag($0) }.map(\.id))
        return matches(tagIDs: assigned)
    }

    public func invalidTagIDs(availableTags: [Tag]) -> Set<Tag.ID> {
        let known = Set(availableTags.map(\.id))
        return Set(operations.map(\.tagID)).subtracting(known)
    }
}

extension TagFilter.Operation: Codable where Tag.ID: Codable {}
extension TagFilter: Codable where Tag.ID: Codable {}

public extension TagUser {
    func matches(_ filter: TagFilter<Tag>, availableTags: [Tag]) -> Bool {
        filter.matches(self, availableTags: availableTags)
    }
}
