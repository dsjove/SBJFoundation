import Foundation
import SBJLocalization

/// Structural inspection adapters for domain-level content semantics.
public enum SBJContentCheck {
    public static func hasContent<T>(_ value: T) -> Bool {
        hasContent(value as Any)
    }

    /// Resolve explicit content behavior first, then use the structural shape.
    /// Scalars, plain enum cases, and other atomic values always have content.
    /// Annotated structs use their generated user-facing content contract; opaque
    /// structs retain the existing aggregate fallback.
    static func hasContent(_ value: Any) -> Bool {
        if let checkable = value as? any HasContentCheckable {
            return checkable.hasContent
        }

        let mirror = Mirror(reflecting: value)
        switch mirror.displayStyle {
        case .optional:
            guard let wrapped = mirror.children.first?.value else { return false }
            return hasContent(wrapped)
        case .collection, .set:
            return mirror.children.contains { hasContent($0.value) }
        case .dictionary:
            return mirror.children.contains { entry in
                let pair = Mirror(reflecting: entry.value)
                guard let member = Array(pair.children).dropFirst().first else { return false }
                return hasContent(member.value)
            }
        case .struct, .tuple:
            // Value structs behave as aggregates, including empty structs.
            return mirror.children.contains { hasContent($0.value) }
        case .enum:
            // A case without associated values is an atomic selection.
            guard let payload = mirror.children.first?.value else { return true }
            return hasContent(payload)
        default:
            return true
        }
    }

    /// Returns `true` when `value` or one of its recursively inspectable children
    /// represents empty content. This is structural model inspection and has no
    /// dependency on SwiftUI or the SBJ editor.
    ///
    /// The optional `treatingAsLeaf` predicate lets a consumer stop traversal at
    /// application-defined atomic types. The generic editor uses this to preserve
    /// custom-editor boundaries; logging and other non-editor callers normally use
    /// the default and inspect the complete structural value tree.
    public static func containsEmptyContent<T>(
        _ value: T,
        treatingAsLeaf: (Any.Type) -> Bool = { _ in false }
    ) -> Bool {
        containsEmptyContent(value as Any, treatingAsLeaf: treatingAsLeaf)
    }

    static func containsEmptyContent(
        _ value: Any,
        treatingAsLeaf: (Any.Type) -> Bool
    ) -> Bool {
        if let checkable = value as? any HasContentCheckable, !checkable.hasContent {
            return true
        }

        if treatingAsLeaf(Swift.type(of: value)) {
            return false
        }

        if let structured = value as? any SBJStructured {
            return structured.sbjContainsEmptyContent(treatingAsLeaf: treatingAsLeaf)
        }

        let mirror = Mirror(reflecting: value)
        switch mirror.displayStyle {
        case .optional:
            guard let wrapped = mirror.children.first?.value else { return true }
            return containsEmptyContent(wrapped, treatingAsLeaf: treatingAsLeaf)

        case .collection, .set:
            return mirror.children.contains {
                containsEmptyContent($0.value, treatingAsLeaf: treatingAsLeaf)
            }

        case .dictionary:
            return mirror.children.contains { entry in
                let pair = Mirror(reflecting: entry.value)
                guard let dictionaryValue = Array(pair.children).dropFirst().first?.value else {
                    return false
                }
                return containsEmptyContent(dictionaryValue, treatingAsLeaf: treatingAsLeaf)
            }

        case .enum where value is any SBJStructuredEnum:
            return mirror.children.contains { child in
                containsEmptyEnumPayload(child.value, treatingAsLeaf: treatingAsLeaf)
            }

        default:
            return false
        }
    }

    private static func containsEmptyEnumPayload(
        _ value: Any,
        treatingAsLeaf: (Any.Type) -> Bool
    ) -> Bool {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .tuple {
            return mirror.children.contains {
                containsEmptyContent($0.value, treatingAsLeaf: treatingAsLeaf)
            }
        }
        return containsEmptyContent(value, treatingAsLeaf: treatingAsLeaf)
    }
}
