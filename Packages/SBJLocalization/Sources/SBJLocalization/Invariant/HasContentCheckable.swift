import Foundation

/// A value that reports whether it contains meaningful information for a user,
/// according to its domain-specific rules. This is independent of stored state,
/// serialization, structural equivalence, and physical container emptiness.
/// Domain invariant validation is also available on request.
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
    public var hasContent: Bool {
        values.contains { ($0 as? any HasContentCheckable)?.hasContent ?? true }
    }

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

