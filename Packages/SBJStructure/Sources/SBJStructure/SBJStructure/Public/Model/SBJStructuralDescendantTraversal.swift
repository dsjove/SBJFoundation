import Foundation
import SBJLocalization

/// One occurrence in the user-facing value graph of an SBJStructured instance.
///
/// `identityPath` uses declaration names and collection identities, never
/// localized labels or display ordinals. `locationPath` records current slots.
/// A positional collection identity is only valid for its original snapshot.
public struct SBJStructuralValueOccurrence {
    public let identityPath: [String]
    public let locationPath: [String]
    public let displayPath: [String]
    public let value: Any
    public let valueType: Any.Type
    public let info: SBJNomenclature?
    public let hints: [SBJPropertyHint]
    /// Declared invariants, distinct from editor usage hints.
    public let constraints: [SBJPropertyConstraint]
    public let isWritableProperty: Bool
    /// Original key on a dictionary entry; nil on other occurrences.
    public let dictionaryKey: Any?
    public let dictionaryKeyType: Any.Type?
    public let isPositional: Bool

    public init(
        identityPath: [String], locationPath: [String], displayPath: [String],
        value: Any, valueType: Any.Type, info: SBJNomenclature?,
        hints: [SBJPropertyHint] = [], constraints: [SBJPropertyConstraint] = [],
        isWritableProperty: Bool, isPositional: Bool,
        dictionaryKey: Any? = nil, dictionaryKeyType: Any.Type? = nil
    ) {
        self.identityPath = identityPath
        self.locationPath = locationPath
        self.displayPath = displayPath
        self.value = value
        self.valueType = valueType
        self.info = info
        self.hints = hints
        self.constraints = constraints
        self.isWritableProperty = isWritableProperty
        self.dictionaryKey = dictionaryKey
        self.dictionaryKeyType = dictionaryKeyType
        self.isPositional = isPositional
    }
}

/// Internal, type-preserving collection projection reused by the recursive
/// structural visitor. Collection identities originate in SBJCollectionTraversal.
public struct SBJStructuralChild {
    public let identity: String
    public let location: String
    public let title: String
    public let value: Any
    /// Original key on a dictionary entry; nil on other occurrences.
    public let dictionaryKey: Any?
    public let dictionaryKeyType: Any.Type?
    public let isPositional: Bool

    public init(identity: String, location: String, title: String, value: Any, isPositional: Bool = false,
                dictionaryKey: Any? = nil, dictionaryKeyType: Any.Type? = nil) {
        self.identity = identity
        self.location = location
        self.title = title
        self.value = value
        self.dictionaryKey = dictionaryKey
        self.dictionaryKeyType = dictionaryKeyType
        self.isPositional = isPositional
    }
}

/// User-facing traversal entry point. A leaf or atomic value is reported once;
/// compound containers are reported and then recursively visited in declaration order.
public extension SBJStructuralTraversal {
    static func descendants<Root: SBJStructured>(in root: Root) -> [SBJStructuralValueOccurrence] {
        root.sbjStructuralDescendants(
            identityPath: [], locationPath: [], displayPath: [], isPositional: false, ancestorsWritable: true
        )
    }

    static func visitDescendants<Root: SBJStructured>(
        in root: Root,
        _ visit: (SBJStructuralValueOccurrence) throws -> Void
    ) rethrows {
        for occurrence in descendants(in: root) { try visit(occurrence) }
    }
}

/// An implementation detail intentionally independent of editor fields/bindings.
/// A protocol extension permits opening any SBJStructured existential without
/// constructing a model or switching on concrete application model types.
public extension SBJStructured {
    func sbjStructuralDescendants(
        identityPath: [String], locationPath: [String],
        displayPath: [String], isPositional: Bool, ancestorsWritable: Bool
    ) -> [SBJStructuralValueOccurrence] {
        guard !SBJStructuralType.isAtomic(Self.self) else { return [] }
        let writableNames: Set<String> = {
            guard let mutable = Self.self as? any SBJMutableStructure.Type else { return [] }
            return mutable._sbjWritableSourceNames()
        }()
        return Self.sbjProperties.enumerated().flatMap { ordinal, property -> [SBJStructuralValueOccurrence] in
            guard property.isUserFacing else { return [] }
            let value = self[keyPath: property.keyPath]
            let identity = identityPath + ["property:\(property.sourceName)"]
            let location = locationPath + ["field:\(ordinal)"]
            let display = displayPath + [property.displayName]
            let entry = SBJStructuralValueOccurrence(
                identityPath: identity, locationPath: location, displayPath: display,
                value: value, valueType: type(of: property.keyPath).valueType, info: property.info,
                hints: property.hints, constraints: property.constraints,
                isWritableProperty: ancestorsWritable && writableNames.contains(property.sourceName),
                isPositional: isPositional
            )
            return [entry] + SBJStructuralValueWalker.children(
                of: value, identityPath: identity, locationPath: location,
                displayPath: display, isPositional: isPositional,
                ancestorsWritable: ancestorsWritable && writableNames.contains(property.sourceName),
                itemTitleKey: SBJStructuralCollectionKeys.title(in: property.hints),
                itemIdentifierKey: SBJStructuralCollectionKeys.identifier(in: property.constraints)
            )
        }

    }
}

public extension SBJMutableStructure {
    static func _sbjWritableSourceNames() -> Set<String> {
        Set(Self.sbjUserFacingProperties.filter { $0.access == .readWrite }.map(\.sourceName))
    }
}

/// Standard containers supply semantic children without requiring reflection.
public protocol SBJStructuralValueContainer {
    func sbjStructuralChildren(itemTitleKey: AnyKeyPath?, itemIdentifierKey: String?) -> [SBJStructuralChild]
}

extension Optional: SBJStructuralValueContainer {
    public func sbjStructuralChildren(itemTitleKey: AnyKeyPath?, itemIdentifierKey: String?) -> [SBJStructuralChild] {
        guard let wrapped = self else { return [] }
        // Optional contents do not introduce an extra identity/location component.
        return [.init(identity: "", location: "", title: "", value: wrapped)]
    }
}

extension Array: SBJStructuralValueContainer {
    public func sbjStructuralChildren(itemTitleKey: AnyKeyPath?, itemIdentifierKey: String?) -> [SBJStructuralChild] {
        SBJCollectionTraversal.array(self, itemTitleKey: itemTitleKey, itemIdentifierKey: itemIdentifierKey).map {
            .init(identity: $0.identifier, location: $0.location, title: $0.title,
                  value: $0.value, isPositional: SBJCollectionTraversal.isPositional($0))
        }
    }
}

extension Set: SBJStructuralValueContainer {
    public func sbjStructuralChildren(itemTitleKey: AnyKeyPath?, itemIdentifierKey: String?) -> [SBJStructuralChild] {
        SBJCollectionTraversal.set(self, itemTitleKey: itemTitleKey).map {
            .init(identity: $0.identifier, location: $0.location, title: $0.title, value: $0.value)
        }
    }
}

extension Dictionary: SBJStructuralValueContainer {
    public func sbjStructuralChildren(itemTitleKey: AnyKeyPath?, itemIdentifierKey: String?) -> [SBJStructuralChild] {
        SBJCollectionTraversal.dictionary(self, itemTitleKey: itemTitleKey).map {
            .init(identity: $0.identifier, location: $0.location, title: $0.title, value: $0.value.value,
                  dictionaryKey: $0.value.key as Any, dictionaryKeyType: Key.self)
        }
    }
}

private final class SBJAssociatedPayloadCollector<Root: SBJStructuredEnum>: SBJTypedAssociatedValueVisitor {
    let value: Root
    var children: [SBJStructuralChild] = []
    init(value: Root) { self.value = value }

    func visit<Value>(
        name: String,
        get: @escaping (Root) -> Value,
        set: @escaping (inout Root, Value) -> Void
    ) {
        children.append(.init(identity: "associated:\(name)", location: "associated:\(name)",
                              title: name, value: get(value)))
    }
}

public extension SBJStructuredEnum {
    func sbjStructuralAssociatedChildren() -> [SBJStructuralChild] {
        guard let active = Self.sbjAssociatedCases.first(where: { $0.matches(self) }) else { return [] }
        let collector = SBJAssociatedPayloadCollector(value: self)
        for property in active.associatedValues { property.visit(collector) }
        return [.init(identity: "case:\(active.sourceName)", location: "case:\(active.sourceName)",
                      title: active.sourceName, value: self)] + collector.children
    }
}

/// Recursion is limited to generated structural declarations, supported
/// containers and generated associated-value metadata; arbitrary Mirror
/// children are deliberately not treated as writable model fields.
public enum SBJStructuralValueWalker {
    public static func children(
        of value: Any,
        identityPath: [String], locationPath: [String], displayPath: [String],
        isPositional: Bool, ancestorsWritable: Bool,
        itemTitleKey: AnyKeyPath? = nil, itemIdentifierKey: String? = nil
    ) -> [SBJStructuralValueOccurrence] {
        if value is any SBJAtomicStructuralValue { return [] }
        if let structured = value as? any SBJStructured {
            return structured.sbjStructuralDescendants(
                identityPath: identityPath, locationPath: locationPath,
                displayPath: displayPath, isPositional: isPositional,
                ancestorsWritable: ancestorsWritable
            )
        }
        if let container = value as? any SBJStructuralValueContainer {
            return container.sbjStructuralChildren(
                itemTitleKey: itemTitleKey, itemIdentifierKey: itemIdentifierKey
            ).flatMap { child in
                let ids = child.identity.isEmpty ? identityPath : identityPath + [child.identity]
                let locations = child.location.isEmpty ? locationPath : locationPath + [child.location]
                let displays = child.title.isEmpty ? displayPath : displayPath + [child.title]
                let positional = isPositional || child.isPositional
                let entry = child.identity.isEmpty ? [] : [SBJStructuralValueOccurrence(
                    identityPath: ids, locationPath: locations, displayPath: displays,
                    value: child.value, valueType: type(of: child.value), info: nil,
                    isWritableProperty: ancestorsWritable, isPositional: positional,
                    dictionaryKey: child.dictionaryKey, dictionaryKeyType: child.dictionaryKeyType
                )]
                return entry + children(of: child.value, identityPath: ids,
                                        locationPath: locations, displayPath: displays,
                                        isPositional: positional, ancestorsWritable: ancestorsWritable,
                                        itemTitleKey: child.identity.isEmpty ? itemTitleKey : nil,
                                        itemIdentifierKey: child.identity.isEmpty ? itemIdentifierKey : nil)
            }
        }
        if let associated = value as? any SBJStructuredEnum {
            // Payloads are generated, typed accessors, not Mirror guesses.
            let parts = associated.sbjStructuralAssociatedChildren()
            guard let casePart = parts.first else { return [] }
            let caseIDs = identityPath + [casePart.identity]
            let caseLocations = locationPath + [casePart.location]
            return parts.dropFirst().flatMap { part in
                let ids = caseIDs + [part.identity]
                let locations = caseLocations + [part.location]
                let displays = displayPath + [part.title]
                let entry = SBJStructuralValueOccurrence(
                    identityPath: ids, locationPath: locations, displayPath: displays,
                    value: part.value, valueType: type(of: part.value), info: nil,
                    isWritableProperty: ancestorsWritable, isPositional: isPositional
                )
                return [entry] + children(of: part.value, identityPath: ids,
                                          locationPath: locations, displayPath: displays,
                                          isPositional: isPositional, ancestorsWritable: ancestorsWritable)
            }
        }
        return []
    }

}

/// Shared extraction of model-declared collection naming and identity policy.
/// The editor and the structural walker must interpret these identically.
public enum SBJStructuralCollectionKeys {
    public static func title(in hints: [SBJPropertyHint]) -> AnyKeyPath? {
        for hint in hints {
            if case .elementName(let value) = hint { return value }
        }
        return nil
    }

    public static func identifier(in constraints: [SBJPropertyConstraint]) -> String? {
        for constraint in constraints {
            if case .uniqueBy(let value) = constraint {
                return value.split(separator: ".").last.map(String.init)
            }
        }
        return nil
    }
}
