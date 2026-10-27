import Foundation

/// Value-level equivalence used by SBJStructure when determining whether model
/// content has structurally changed.
///
/// Structural equivalence is intentionally independent of application mutation
/// history. Generated `@SBJStructure` models compare their coded properties
/// recursively, collections compare their contents recursively, ordinary
/// `Equatable` values use `==`, and opaque `Encodable` values fall back to a
/// stable encoded representation.
public protocol SBJStructuralComparable {
    func sbjStructuralEquals(_ other: Self) -> Bool

    /// Type-erased bridge used by the generic structural comparison dispatcher.
    func _sbjStructuralEqualsAny(_ other: Any) -> Bool
}

public extension SBJStructuralComparable {
    func _sbjStructuralEqualsAny(_ other: Any) -> Bool {
        guard let other = other as? Self else { return false }
        return sbjStructuralEquals(other)
    }
}

/// Central structural-equivalence dispatcher.
///
/// Dispatch order is deliberate:
/// 1. SBJ structural values (including generated models and collections),
/// 2. ordinary `Equatable` values,
/// 3. stable encoded comparison as the fallback for opaque Codable values.
public enum SBJStructuralCompare {
    public static func equals<Value>(_ lhs: Value, _ rhs: Value) -> Bool {
        if let structural = lhs as? any SBJStructuralComparable {
            return structural._sbjStructuralEqualsAny(rhs)
        }
        if let equatable = lhs as? any Equatable {
            return _equalsEquatable(equatable, rhs)
        }
        if let left = lhs as? any Encodable, let right = rhs as? any Encodable {
            return _encodedEquals(left, right)
        }
        return String(describing: lhs) == String(describing: rhs)
    }

    private static func _equalsEquatable<Value: Equatable>(_ lhs: Value, _ rhs: Any) -> Bool {
        guard let rhs = rhs as? Value else { return false }
        return lhs == rhs
    }

    private static func _encodedEquals(_ lhs: any Encodable, _ rhs: any Encodable) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let left = try? encoder.encode(lhs),
              let right = try? encoder.encode(rhs) else {
            return String(describing: lhs) == String(describing: rhs)
        }
        return left == right
    }
}

public extension Encodable {
    /// Structural equality for opaque Codable values. When invoked on a concrete
    /// generated SBJ model or collection, that type's more specific implementation
    /// is used instead.
    func sbjStructuralEquals(_ other: Self) -> Bool {
        SBJStructuralCompare.equals(self, other)
    }
}

extension Optional: SBJStructuralComparable where Wrapped: Encodable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        switch (self, other) {
        case (nil, nil):
            return true
        case let (.some(lhs), .some(rhs)):
            return SBJStructuralCompare.equals(lhs, rhs)
        default:
            return false
        }
    }
}

extension Array: SBJStructuralComparable where Element: Encodable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        guard count == other.count else { return false }
        return zip(self, other).allSatisfy { lhs, rhs in
            SBJStructuralCompare.equals(lhs, rhs)
        }
    }
}

extension Set: SBJStructuralComparable where Element: Encodable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        guard count == other.count else { return false }
        return allSatisfy { lhs in
            guard let index = other.firstIndex(of: lhs) else { return false }
            return SBJStructuralCompare.equals(lhs, other[index])
        }
    }
}

extension Dictionary: SBJStructuralComparable where Key: Encodable, Value: Encodable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        guard count == other.count else { return false }
        return allSatisfy { key, lhs in
            guard let index = other.index(forKey: key) else { return false }
            return SBJStructuralCompare.equals(lhs, other[index].value)
        }
    }
}
