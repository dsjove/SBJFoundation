import Foundation

/// Exact logical stored-value equivalence, independent of user-facing meaning,
/// serialization, and application-defined equality. Allocation addresses,
/// collection capacity, hash-table ordering and memory padding are not state.
/// Implementations must compare all stored values relevant to this contract.
public protocol SBJStructuralComparable {
    func sbjStructuralEquals(_ other: Self) -> Bool
    func _sbjStructuralEqualsAny(_ other: Any) -> Bool
}

public extension SBJStructuralComparable {
    func _sbjStructuralEqualsAny(_ other: Any) -> Bool {
        guard ObjectIdentifier(type(of: self)) == ObjectIdentifier(type(of: other)),
              let other = other as? Self else { return false }
        return sbjStructuralEquals(other)
    }
}

/// Explicit opt-in for opaque scalar values whose equality is their complete
/// logical value. Do not adopt this for identity-based or partial equality.
public protocol SBJStructuralScalar: SBJStructuralComparable, Equatable {}

public extension SBJStructuralScalar {
    func sbjStructuralEquals(_ other: Self) -> Bool { self == other }
}

/// Only explicit structural comparisons establish equivalence. Unsupported
/// types conservatively compare unequal, even to themselves. Neither Codable,
/// Equatable nor a textual description is evidence of complete stored state.
public enum SBJStructuralCompare {
    public static func equals<Value>(_ lhs: Value, _ rhs: Value) -> Bool {
        guard ObjectIdentifier(type(of: lhs as Any)) == ObjectIdentifier(type(of: rhs as Any)),
              let structural = lhs as? any SBJStructuralComparable else { return false }
        return structural._sbjStructuralEqualsAny(rhs)
    }
}

extension Bool: SBJStructuralScalar {}
extension Int: SBJStructuralScalar {}
extension Int8: SBJStructuralScalar {}
extension Int16: SBJStructuralScalar {}
extension Int32: SBJStructuralScalar {}
extension Int64: SBJStructuralScalar {}
extension UInt: SBJStructuralScalar {}
extension UInt8: SBJStructuralScalar {}
extension UInt16: SBJStructuralScalar {}
extension UInt32: SBJStructuralScalar {}
extension UInt64: SBJStructuralScalar {}
extension UUID: SBJStructuralScalar {}
extension Data: SBJStructuralScalar {}

// Compare the actual UTF-8 sequence, not Swift's canonical Unicode equality.
extension String: SBJStructuralComparable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        utf8.elementsEqual(other.utf8)
    }
}
extension Character: SBJStructuralComparable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        String(self).sbjStructuralEquals(String(other))
    }
}

// Bit patterns distinguish signed zero and preserve NaN payloads.
extension Float: SBJStructuralComparable {
    public func sbjStructuralEquals(_ other: Self) -> Bool { bitPattern == other.bitPattern }
}
extension Double: SBJStructuralComparable {
    public func sbjStructuralEquals(_ other: Self) -> Bool { bitPattern == other.bitPattern }
}
#if arch(arm64) || os(Linux)
extension Float16: SBJStructuralComparable {
    public func sbjStructuralEquals(_ other: Self) -> Bool { bitPattern == other.bitPattern }
}
#endif
extension CGFloat: SBJStructuralComparable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        native.sbjStructuralEquals(other.native)
    }
}
extension Date: SBJStructuralComparable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        timeIntervalSinceReferenceDate.sbjStructuralEquals(other.timeIntervalSinceReferenceDate)
    }
}
extension URL: SBJStructuralComparable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        relativeString.sbjStructuralEquals(other.relativeString)
            && baseURL.sbjStructuralEquals(other.baseURL)
    }
}
extension Duration: SBJStructuralComparable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        components.seconds == other.components.seconds
            && components.attoseconds == other.components.attoseconds
    }
}

// Decimal exposes a logical numeric value, not a stable byte representation.
// Compare its documented value and exponent/sign, not private Foundation storage.
extension Decimal: SBJStructuralComparable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        (isNaN && other.isNaN) || (self == other && exponent == other.exponent && isSignMinus == other.isSignMinus)
    }
}

extension Optional: SBJStructuralComparable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        switch (self, other) {
        case (nil, nil): return true
        case let (.some(lhs), .some(rhs)): return SBJStructuralCompare.equals(lhs, rhs)
        default: return false
        }
    }
}

extension Array: SBJStructuralComparable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        count == other.count && zip(self, other).allSatisfy { lhs, rhs in
            SBJStructuralCompare.equals(lhs, rhs)
        }
    }
}

extension Set: SBJStructuralComparable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        guard count == other.count else { return false }
        if allSatisfy({ lhs in
            guard let index = other.firstIndex(of: lhs) else { return false }
            return SBJStructuralCompare.equals(lhs, other[index])
        }) { return true }
        // Hashable equality can be identity-based. Match each structural value
        // exactly once instead of using Hashable as the equivalence definition.
        var unmatched = Array(other)
        for lhs in self {
            guard let index = unmatched.firstIndex(where: { SBJStructuralCompare.equals(lhs, $0) }) else { return false }
            unmatched.remove(at: index)
        }
        return true
    }
}

extension Dictionary: SBJStructuralComparable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        guard count == other.count else { return false }
        if allSatisfy({ key, value in
            guard let index = other.index(forKey: key) else { return false }
            let entry = other[index]
            return SBJStructuralCompare.equals(key, entry.key)
                && SBJStructuralCompare.equals(value, entry.value)
        }) { return true }
        var unmatched = Array(other)
        for (key, value) in self {
            guard let index = unmatched.firstIndex(where: {
                SBJStructuralCompare.equals(key, $0.key)
                    && SBJStructuralCompare.equals(value, $0.value)
            }) else { return false }
            unmatched.remove(at: index)
        }
        return true
    }
}
