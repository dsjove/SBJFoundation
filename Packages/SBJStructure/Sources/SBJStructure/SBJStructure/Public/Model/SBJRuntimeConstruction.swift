import Foundation

/// Typed, UI-independent construction of SBJStructure values from JSON object fields.
/// Input keys may use Swift member names, initializer labels, or member nomenclature.
/// No source code is generated or executed at runtime.
public enum SBJRuntimeConstruction {
    public enum Failure: Error, Equatable {
        case expectedObject
        case unknownMember(String)
        case ambiguousMember(String)
        case duplicateMember(String)
        case invalidValue(String)
        case decodingFailed
    }

    /// Returns canonical Swift property names, rejecting unrecognized and ambiguous names.
    /// Renaming is performed before Decodable sees the input. A constructor parameter's
    /// external label is an alias for its actual stored member, never a separate field.
    private static func canonicalFields<T: SBJStructured>(
        _ supplied: [String: Any], for type: T.Type
    ) throws -> [String: Any] {
        let members = type.sbjProperties
        let initializerMembers = type.sbjInitializerMembers
        var resolved: [String: Any] = [:]
        for (name, value) in supplied {
            let matches = members.filter { property in
                let labels = [property.sourceName, property.displayName] +
                    (property.info.map { [$0.title] + $0.aliases } ?? []) +
                    initializerMembers.filter { $0.parameter.propertyName == property.sourceName }
                        .flatMap { [$0.parameter.label].compactMap { $0 } }
                return labels.contains {
                    !$0.isEmpty && $0.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                }
            }
            guard !matches.isEmpty else { throw Failure.unknownMember(name) }
            guard matches.count == 1 else { throw Failure.ambiguousMember(name) }
            let canonical = matches[0].sourceName
            guard resolved[canonical] == nil else { throw Failure.duplicateMember(canonical) }
            resolved[canonical] = value
        }
        return resolved
    }

    private static func object(from data: Data) throws -> [String: Any] {
        let value = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        guard let object = value as? [String: Any] else { throw Failure.expectedObject }
        return object
    }

    /// Codable reconstruction supports immutable `let` fields and models without
    /// a default initializer. When a default exists, omitted fields keep defaults.
    /// The model's own decoding contract, not Swift initializer-source syntax,
    /// determines whether the resulting object can actually be constructed.
    public static func construct<T: SBJStructured>(
        _ type: T.Type, fromJSON data: Data
    ) throws -> T {
        let fields = try canonicalFields(object(from: data), for: type)
        var representation: [String: Any] = [:]
        if let initial = type.sbjDefaultValue() {
            let encoded = try JSONEncoder().encode(initial)
            representation = try object(from: encoded)
        }
        for (name, value) in fields { representation[name] = value }
        let bytes = try JSONSerialization.data(withJSONObject: representation, options: [.fragmentsAllowed])
        let candidate = try JSONDecoder().decode(type, from: bytes)
        try SBJInvariantCheck.validate(candidate, at: .root)
        return candidate
    }

    /// For mutable models, construct through the existing typed writable-property
    /// visitors first. This preserves default initialization and setter semantics.
    /// Immutable members are handled by the Codable path, rather than ignored.
    public static func construct<T: SBJMutableStructure>(
        _ type: T.Type, fromJSON data: Data
    ) throws -> T {
        let fields = try canonicalFields(object(from: data), for: type)
        guard var candidate = type.sbjDefaultValue() else {
            return try constructViaCodable(type, fields: fields)
        }
        let writable = type.sbjMutableProperties.filter { $0.participatesInStructuralValidation }
        let byName = Dictionary(uniqueKeysWithValues: writable.map {
            (($0.structuralMetadata?.sourceName ?? $0.name), $0)
        })
        // A supplied immutable field requires atomic reconstruction by Decodable.
        if fields.keys.contains(where: { byName[$0] == nil }) {
            return try constructViaCodable(type, fields: fields)
        }
        for property in type.sbjProperties {
            guard let jsonValue = fields[property.sourceName],
                  let writableProperty = byName[property.sourceName] else { continue }
            let visitor = SBJRuntimePropertyDecoder<T>(jsonValue: jsonValue)
            guard writableProperty.visitTypedProperty(with: visitor),
                  visitor.error == nil, let value = visitor.value,
                  writableProperty.setValue(value, in: &candidate) else {
                throw Failure.invalidValue(property.sourceName)
            }
        }
        try SBJInvariantCheck.validate(candidate, at: .root)
        return candidate
    }

    private static func constructViaCodable<T: SBJStructured>(
        _ type: T.Type, fields: [String: Any]
    ) throws -> T {
        var representation: [String: Any] = [:]
        if let initial = type.sbjDefaultValue() {
            representation = try object(from: JSONEncoder().encode(initial))
        }
        for (name, value) in fields { representation[name] = value }
        let data = try JSONSerialization.data(withJSONObject: representation, options: [.fragmentsAllowed])
        let candidate = try JSONDecoder().decode(type, from: data)
        try SBJInvariantCheck.validate(candidate, at: .root)
        return candidate
    }
}

private final class SBJRuntimePropertyDecoder<Root: SBJStructured>: SBJTypedStructuralPropertyVisitor {
    let jsonValue: Any
    var value: Any?
    var error: Error?

    init(jsonValue: Any) { self.jsonValue = jsonValue }

    func visit<Value: Codable>(
        _ keyPath: WritableKeyPath<Root, Value>,
        metadata: SBJPropertyMetadata<Root>?
    ) {
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonValue, options: [.fragmentsAllowed])
            value = try JSONDecoder().decode(Value.self, from: data) as Any
        } catch { self.error = error }
    }
}
