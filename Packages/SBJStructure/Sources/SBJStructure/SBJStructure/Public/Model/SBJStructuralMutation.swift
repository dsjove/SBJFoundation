import Foundation

/// An implementation detail shared by structured models and supported containers.
/// This is a value operation: failure never mutates its receiver.
public protocol SBJStructuralMutationNode {
    func sbjReplacingStructuralValue(at location: ArraySlice<String>, with replacement: Any) throws -> Any
}

public enum SBJStructuralMutationError: Error, Equatable {
    case invalidLocation
    case immutableProperty
    case typeMismatch
    case unsupportedContainer
    case collectionCollision
}

/// Apply a resolved *current location*, never an AI-generated key path.
/// The caller must resolve identity and guard positional revisions first.
public enum SBJStructuralMutation {
    public static func replacing<Value>(
        _ current: Value, at location: ArraySlice<String>, with replacement: Any
    ) throws -> Value {
        if location.isEmpty {
            guard let typed = replacement as? Value else { throw SBJStructuralMutationError.typeMismatch }
            return typed
        }
        guard let node = current as? any SBJStructuralMutationNode else {
            throw SBJStructuralMutationError.unsupportedContainer
        }
        guard let value = try node.sbjReplacingStructuralValue(at: location, with: replacement) as? Value else {
            throw SBJStructuralMutationError.typeMismatch
        }
        return value
    }
}

public extension SBJMutableStructure {
    func sbjReplacingStructuralValue(at location: ArraySlice<String>, with replacement: Any) throws -> Any {
        guard let head = location.first, head.hasPrefix("field:"),
              let ordinal = Int(head.dropFirst("field:".count)),
              Self.sbjProperties.indices.contains(ordinal) else {
            throw SBJStructuralMutationError.invalidLocation
        }
        let name = Self.sbjProperties[ordinal].sourceName
        let writable = Self._sbjWritableSourceNames()
        guard writable.contains(name),
              let property = Self.sbjMutableProperties.first(where: {
                  $0.participatesInStructuralValidation &&
                  ($0.structuralMetadata?.sourceName ?? $0.name) == name
              }) else {
            throw SBJStructuralMutationError.immutableProperty
        }
        let old = property.value(in: self)
        let next = try SBJStructuralMutation.replacing(old, at: location.dropFirst(), with: replacement)
        var copy = self
        guard property.setValue(next, in: &copy) else { throw SBJStructuralMutationError.typeMismatch }
        return copy
    }
}

extension Optional: SBJStructuralMutationNode {
    public func sbjReplacingStructuralValue(at location: ArraySlice<String>, with replacement: Any) throws -> Any {
        guard let wrapped = self else { throw SBJStructuralMutationError.invalidLocation }
        let next: Wrapped = try SBJStructuralMutation.replacing(wrapped, at: location, with: replacement)
        return Optional.some(next) as Any
    }
}

extension Array: SBJStructuralMutationNode {
    public func sbjReplacingStructuralValue(at location: ArraySlice<String>, with replacement: Any) throws -> Any {
        guard let head = location.first, head.hasPrefix("index:"),
              let index = Int(head.dropFirst("index:".count)), indices.contains(index) else {
            throw SBJStructuralMutationError.invalidLocation
        }
        var copy = self
        copy[index] = try SBJStructuralMutation.replacing(copy[index], at: location.dropFirst(), with: replacement)
        return copy
    }
}

extension Dictionary: SBJStructuralMutationNode {
    public func sbjReplacingStructuralValue(at location: ArraySlice<String>, with replacement: Any) throws -> Any {
        guard let head = location.first,
              let key = keys.first(where: { "key:\(String(reflecting: $0))" == head }),
              let current = self[key] else { throw SBJStructuralMutationError.invalidLocation }
        var copy = self
        copy[key] = try SBJStructuralMutation.replacing(current, at: location.dropFirst(), with: replacement)
        return copy
    }
}

extension Set: SBJStructuralMutationNode {
    public func sbjReplacingStructuralValue(at location: ArraySlice<String>, with replacement: Any) throws -> Any {
        guard let head = location.first,
              let current = first(where: {
                  "item:\(String(reflecting: type(of: $0))):\(String(reflecting: $0))" == head
              }) else { throw SBJStructuralMutationError.invalidLocation }
        let updated: Element = try SBJStructuralMutation.replacing(current, at: location.dropFirst(), with: replacement)
        var copy = self
        copy.remove(current)
        guard !copy.contains(updated) else { throw SBJStructuralMutationError.collectionCollision }
        copy.insert(updated)
        return copy
    }
}
