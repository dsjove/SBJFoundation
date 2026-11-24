import Foundation

/// Shared interpretation of existing usage hints. Swift mutation capabilities
/// and invariant validation remain independent of this editor policy.
public enum SBJUsageConsumer: Sendable {
    case visualEditor
    case semanticEditor
    case report
}

public enum SBJUsagePolicy {
    /// Exclusion limits editing/discovery in editors, not report visibility.
    public static func isVisible(_ hints: [SBJPropertyHint], to consumer: SBJUsageConsumer) -> Bool {
        if case .report = consumer { return true }
        return !hints.contains { hint in
            if case .fieldPresentation(let value) = hint { return value.exclude }
            return false
        }
    }

    /// Effective editor operations: intersect these with the collection node's
    /// actual typed operations. No hint ever grants a structural capability.
    public static func allowedCollectionOperations(
        _ supported: Set<SBJCollectionOperationKind>,
        hints: [SBJPropertyHint],
        consumer: SBJUsageConsumer
    ) -> Set<SBJCollectionOperationKind> {
        guard isVisible(hints, to: consumer) else { return [] }
        if case .report = consumer { return supported }
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
