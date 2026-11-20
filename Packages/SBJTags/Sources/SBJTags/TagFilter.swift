import Foundation

/// An ordered set expression over tags. Start with everything or nothing;
/// successive matching rules include or exclude items. Stable tag identifiers
/// allow unknown/deleted tags to remain visible to editors.
public struct TagFilter<Tag: Tagging>: Equatable where Tag.ID: Hashable {
    public struct Operation: Equatable {
        public enum Criterion: Equatable {
            case tag(Tag.ID)
            case hasTag

            func matches(_ assigned: Set<Tag.ID>) -> Bool {
                switch self {
                case .tag(let id): assigned.contains(id)
                case .hasTag: !assigned.isEmpty
                }
            }
        }

        public var criterion: Criterion
        public var add: Bool

        public init(tagID: Tag.ID, add: Bool) {
            self.init(criterion: .tag(tagID), add: add)
        }

        public init(criterion: Criterion, add: Bool) {
            self.criterion = criterion
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
        for operation in operations where operation.criterion.matches(tagIDs) {
            included = operation.add
        }
        return included
    }

    /// A TagUser predicate using its existing SBJTags relationship API.
    /// Unresolved tag rules cannot match, but remain available to the UI.
    public func matches<User: TagUser>(_ user: User, availableTags: [Tag]) -> Bool where User.Tag == Tag {
        let assigned = Set(availableTags.filter { user.hasTag($0) }.map(\.id))
        return matches(tagIDs: assigned)
    }

    public func invalidTagIDs(availableTags: [Tag]) -> Set<Tag.ID> {
        let known = Set(availableTags.map(\.id))
        let referenced = operations.compactMap { operation -> Tag.ID? in
            if case .tag(let id) = operation.criterion { return id }
            return nil
        }
        return Set(referenced).subtracting(known)
    }
}

// Preserve the on-disk shape of existing named-tag operations (tagID/add).
// New cardinality conditions encode with a separate `condition` key.
extension TagFilter.Operation: Codable where Tag.ID: Codable {
    private enum CodingKeys: String, CodingKey { case tagID, condition, add }
    private enum Condition: String, Codable { case hasTag }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        add = try values.decode(Bool.self, forKey: .add)
        if let condition = try values.decodeIfPresent(Condition.self, forKey: .condition) {
            switch condition {
            case .hasTag: criterion = .hasTag
            }
        } else {
            criterion = .tag(try values.decode(Tag.ID.self, forKey: .tagID))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(add, forKey: .add)
        switch criterion {
        case .tag(let id): try values.encode(id, forKey: .tagID)
        case .hasTag: try values.encode(Condition.hasTag, forKey: .condition)
        }
    }
}

// Legacy Has No Tag rules matched only empty assignments. An ordered filter cannot
// replace one with an inverted Has Tag rule in isolation: earlier/later rules and
// startAll also matter. Preserve the result for BOTH empty and nonempty assignments
// by setting the new starting state to the final empty-assignment result, and
// restoring the original starting state for nonempty assignments with a first rule.
extension TagFilter: Codable where Tag.ID: Codable {
    private enum CodingKeys: String, CodingKey { case startAll, operations }

    private struct StoredOperation: Decodable {
        private enum Keys: String, CodingKey { case tagID, condition, add }
        enum Target { case tag(Tag.ID), hasTag, legacyHasNoTag }
        let target: Target
        let add: Bool

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: Keys.self)
            add = try values.decode(Bool.self, forKey: .add)
            if let condition = try values.decodeIfPresent(String.self, forKey: .condition) {
                switch condition {
                case "hasTag": target = .hasTag
                case "hasNoTag": target = .legacyHasNoTag
                default:
                    throw DecodingError.dataCorruptedError(
                        forKey: .condition, in: values, debugDescription: "Unknown tag-filter condition")
                }
            } else {
                target = .tag(try values.decode(Tag.ID.self, forKey: .tagID))
            }
        }
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let originalStart = try values.decode(Bool.self, forKey: .startAll)
        let stored = try values.decode([StoredOperation].self, forKey: .operations)
        var operations: [Operation] = []
        var emptyResult = originalStart
        var hasLegacyRule = false
        for entry in stored {
            switch entry.target {
            case .tag(let id): operations.append(.init(tagID: id, add: entry.add))
            case .hasTag: operations.append(.init(criterion: .hasTag, add: entry.add))
            case .legacyHasNoTag:
                emptyResult = entry.add
                hasLegacyRule = true
            }
        }
        if hasLegacyRule {
            operations.insert(.init(criterion: .hasTag, add: originalStart), at: 0)
        }
        self.init(startAll: emptyResult, operations: operations)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(startAll, forKey: .startAll)
        try values.encode(operations, forKey: .operations)
    }
}

public extension TagUser {
    func matches(_ filter: TagFilter<Tag>, availableTags: [Tag]) -> Bool {
        filter.matches(self, availableTags: availableTags)
    }
}
