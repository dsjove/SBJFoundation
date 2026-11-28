import Foundation

public enum SBJUsagePolicy {
    /// Explicit presentation exclusion, independent of traversal selection.
    public static func isPresentationExcluded(_ hints: [SBJPropertyHint]) -> Bool {
        hints.contains { hint in
            if case .fieldPresentation(let value) = hint { return value.exclude }
            return false
        }
    }

    /// Effective editor operations: intersect these with the collection node's
    /// actual typed operations. No hint ever grants a structural capability.
    public static func allowedCollectionOperations(
        _ supported: Set<SBJCollectionOperationKind>,
        hints: [SBJPropertyHint]
    ) -> Set<SBJCollectionOperationKind> {
        var allowed = supported
        for hint in hints {
            switch hint {
            case .arrayPresentation(let value):
                if !value.insertable { allowed.subtract([.append, .insert, .duplicate]) }
                if !value.removable { allowed.subtract([.remove, .clear]) }
                if !value.reorderable { allowed.remove(.move) }
            case .setPresentation(let value):
                if !value.insertable { allowed.remove(.insertMember) }
                if !value.removable { allowed.subtract([.removeMember, .remove, .clear]) }
            case .dictionaryPresentation(let value):
                if !value.insertable { allowed.subtract([.insertKey, .putKey]) }
                if !value.removable { allowed.subtract([.removeKey, .remove, .clear]) }
            default: break
            }
        }
        return allowed
    }

    public static func canChangeUnit(_ constraints: [SBJPropertyConstraint]) -> Bool {
        !constraints.contains { constraint in
            switch constraint {
            case .unitMutable(false), .requiredUnit: return true
            default: return false
            }
        }
    }
}
