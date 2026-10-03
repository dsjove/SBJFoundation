import Foundation

/// A value that can report whether it contains meaningful content and validate
/// its own domain invariants when explicitly requested.
public protocol HasContentCheckable {
    var hasContent: Bool { get }
    func invariant(at keyPath: SBJValidationKeyPath) throws
}

public extension HasContentCheckable {
    func invariant(at keyPath: SBJValidationKeyPath) throws {}

    func invariant<Root>(at keyPath: KeyPath<Root, Self>) throws {
        try invariant(at: SBJValidationKeyPath(keyPath))
    }

    /// Runs invariant validation in debug builds and compiles to a no-op in production.
    /// This is intended for client-side invariant probes that should have no release cost.
    @inline(__always)
    func debugInvariant(at keyPath: SBJValidationKeyPath = .root) throws {
#if DEBUG
        try invariant(at: keyPath)
#endif
    }

    /// Key-path convenience overload for debug-only invariant validation.
    @inline(__always)
    func debugInvariant<Root>(at keyPath: KeyPath<Root, Self>) throws {
#if DEBUG
        try invariant(at: SBJValidationKeyPath(keyPath))
#endif
    }
}

extension String: HasContentCheckable {
    public var hasContent: Bool { !isEmpty }
}

extension Data: HasContentCheckable {
    public var hasContent: Bool { !isEmpty }
}

extension Optional: HasContentCheckable {
    public var hasContent: Bool {
        switch self {
        case .none: return false
        case .some(let wrapped):
            return (wrapped as? any HasContentCheckable)?.hasContent ?? true
        }
    }

    public func invariant(at keyPath: SBJValidationKeyPath) throws {
        guard case .some(let wrapped) = self,
              let checkable = wrapped as? any HasContentCheckable else { return }
        try checkable.invariant(at: keyPath)
    }
}

extension Array: HasContentCheckable {
    public var hasContent: Bool {
        guard !isEmpty else { return false }
        return contains { ($0 as? any HasContentCheckable)?.hasContent ?? true }
    }

    public func invariant(at keyPath: SBJValidationKeyPath) throws {
        for (index, element) in enumerated() {
            if let checkable = element as? any HasContentCheckable {
                try checkable.invariant(at: keyPath.appending(index: index))
            }
        }
    }
}

extension Set: HasContentCheckable {
    public var hasContent: Bool {
        guard !isEmpty else { return false }
        return contains { ($0 as? any HasContentCheckable)?.hasContent ?? true }
    }

    public func invariant(at keyPath: SBJValidationKeyPath) throws {
        for element in self {
            if let checkable = element as? any HasContentCheckable {
                try checkable.invariant(at: keyPath.appending(element: element))
            }
        }
    }
}

extension Dictionary: HasContentCheckable {
    public var hasContent: Bool { !isEmpty }

    public func invariant(at keyPath: SBJValidationKeyPath) throws {
        for (key, value) in self {
            if let checkable = value as? any HasContentCheckable {
                try checkable.invariant(at: keyPath.appending(key: key))
            }
        }
    }
}

public extension Sequence {
    var hasContent: Bool {
        var iterator = makeIterator()
        guard let first = iterator.next() else { return false }
        if let checkable = first as? any HasContentCheckable {
            if checkable.hasContent { return true }
            while let element = iterator.next() {
                if (element as? any HasContentCheckable)?.hasContent ?? true { return true }
            }
            return false
        }
        return true
    }
}

public enum SBJContentCheck {
    public static func hasContent<T>(_ value: T) -> Bool {
        (value as? any HasContentCheckable)?.hasContent ?? false
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
