import Foundation
import SBJLocalization

/// Domain-independent operations supported by the structural collection engine.
/// Optional is a collection with cardinality zero or one.
public enum SBJCollectionOperationKind: String, CaseIterable, Hashable, Sendable {
    case append, insert, remove, replace, move, duplicate, clear
    case putKey, insertKey, replaceKey, removeKey, insertMember, replaceMember, removeMember
    case setOptional, clearOptional
}

/// Operation vocabulary is separate from implementation, just as property
/// nomenclature is separate from generated structural property descriptors.
/// An application may offer additional domain vocabulary at the adapter level.
public enum SBJCollectionOperationNomenclature {
    public static func info(for kind: SBJCollectionOperationKind) -> SBJNomenclature {
        switch kind {
        case .append: .init(title: "Append", summary: "Add an element to the end of a sequence", aliases: ["push"])
        case .insert: .init(title: "Insert", summary: "Insert an element at a sequence position")
        case .remove: .init(title: "Remove", summary: "Remove an element at a sequence position", aliases: ["delete"])
        case .replace: .init(title: "Replace", summary: "Replace one sequence element")
        case .move: .init(title: "Move", summary: "Reorder an element within a sequence", aliases: ["reorder"])
        case .duplicate: .init(title: "Duplicate", summary: "Copy an existing sequence element", aliases: ["copy"])
        case .clear: .init(title: "Clear", summary: "Remove every collection element", aliases: ["remove all"])
        case .putKey: .init(title: "Set Entry", summary: "Insert or update a dictionary entry")
        case .insertKey: .init(title: "Insert Entry", summary: "Insert a dictionary key that does not yet exist")
        case .replaceKey: .init(title: "Replace Entry", summary: "Update an existing dictionary key")
        case .removeKey: .init(title: "Remove Entry", summary: "Remove a dictionary entry")
        case .insertMember: .init(title: "Add Member", summary: "Insert a unique set member")
        case .replaceMember: .init(title: "Replace Member", summary: "Replace a member without creating a duplicate")
        case .removeMember: .init(title: "Remove Member", summary: "Remove a set member")
        case .setOptional: .init(title: "Set Value", summary: "Create or replace an optional value")
        case .clearOptional: .init(title: "Clear Value", summary: "Remove an optional value", aliases: ["nil", "unset"])
        }
    }

    /// Returns all operations described by this term. Synonyms are intentionally
    /// not globally unique ("remove" can refer to multiple container kinds).
    /// The caller must intersect the results with the target's capabilities.
    public static func matching(_ term: String) -> [SBJCollectionOperationKind] {
        let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        return SBJCollectionOperationKind.allCases.filter { kind in
            let info = info(for: kind)
            return ([kind.rawValue] + (info.nonEmptyTitle.map { [$0] } ?? []) + info.aliases)
                .contains { $0.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        }
    }
}

/// Typed operation intent. Values are concrete Swift values, never AI-supplied
/// JSON representations of entire collections. Indexes are zero-based at this
/// layer; conversational ordinals are converted by the adapter.
public enum SBJStructuralCollectionOperation {
    case append(Any)
    case insert(Any, at: Int)
    case remove(at: Int)
    case replace(at: Int, with: Any)
    /// `to` is the index in the resulting array, after removing `from`.
    case move(from: Int, to: Int)
    case duplicate(at: Int)
    case clear
    /// Operations against a location obtained from structural discovery.
    /// These tokens are not user-facing names or AI-generated paths.
    case removeElement(atLocation: String)
    case replaceElement(atLocation: String, with: Any)
    case moveElement(atLocation: String, to: Int)
    case duplicateElement(atLocation: String)
    case put(key: Any, value: Any)
    case insertKey(key: Any, value: Any)
    case replaceKey(key: Any, value: Any)
    case removeKey(Any)
    case insertMember(Any)
    case replaceMember(old: Any, new: Any)
    case removeMember(Any)
    case setOptional(Any)
    case clearOptional

    public var kind: SBJCollectionOperationKind {
        switch self {
        case .append: .append
        case .insert: .insert
        case .remove, .removeElement: .remove
        case .replace, .replaceElement: .replace
        case .move, .moveElement: .move
        case .duplicate, .duplicateElement: .duplicate
        case .clear: .clear
        case .put: .putKey
        case .insertKey: .insertKey
        case .replaceKey: .replaceKey
        case .removeKey: .removeKey
        case .insertMember: .insertMember
        case .replaceMember: .replaceMember
        case .removeMember: .removeMember
        case .setOptional: .setOptional
        case .clearOptional: .clearOptional
        }
    }
}

public enum SBJStructuralCollectionOperationError: Error, LocalizedError, Equatable {
    case unsupportedOperation
    case typeMismatch
    case invalidIndex
    case missingElement
    case collectionCollision

    public var errorDescription: String? {
        switch self {
        case .unsupportedOperation: "This operation is not supported by the selected collection."
        case .typeMismatch: "The supplied value is not the required element or key type."
        case .invalidIndex: "The selected collection position is not available."
        case .missingElement: "The selected element does not exist in this collection."
        case .collectionCollision: "That operation would create a duplicate or overwrite an existing element."
        }
    }
}

/// A type-erased entry point whose implementations cast back to the *actual*
/// element and key types. No reflection, registration, or model reconstruction.
public enum SBJCollectionScalarRole: Sendable { case element, key }

/// Strict conversion from conversational text to a known Swift primitive type.
/// Complex elements require an application-specific constructor; never fabricate
/// a model value from an untyped language-model string.
public enum SBJCollectionScalar {
    public static func parse<T>(_ text: String, as type: T.Type) throws -> Any {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if T.self == String.self { return text }
        if T.self == Int.self, let value = Int(trimmed) { return value }
        if T.self == Int64.self, let value = Int64(trimmed) { return value }
        if T.self == Double.self, let value = Double(trimmed), value.isFinite { return value }
        if T.self == Float.self, let value = Float(trimmed), value.isFinite { return value }
        if T.self == Bool.self, let value = Bool(trimmed.lowercased()) { return value }
        if trimmed.first == "{",
           let structured = T.self as? any SBJStructured.Type,
           let data = trimmed.data(using: .utf8) {
            return try structured.sbjConstructRuntime(fromJSON: data)
        }
        throw SBJStructuralCollectionOperationError.typeMismatch
    }
}

public protocol SBJStructuralCollectionNode {
    var sbjSupportedCollectionOperations: Set<SBJCollectionOperationKind> { get }
    func sbjApplyingCollectionOperation(_ operation: SBJStructuralCollectionOperation) throws -> Any
    func sbjParseCollectionScalar(_ text: String, role: SBJCollectionScalarRole) throws -> Any
    /// Creates a new element using the same model factory as the visual editor.
    func sbjCreateCollectionElement() -> Any?
}

public extension SBJStructuralCollectionNode {
    func sbjCreateCollectionElement() -> Any? { nil }
    func sbjParseCollectionScalar(_ text: String, role: SBJCollectionScalarRole) throws -> Any {
        throw SBJStructuralCollectionOperationError.typeMismatch
    }
}

public enum SBJStructuralCollectionMutation {
    public static func supportedOperations(for value: Any) -> Set<SBJCollectionOperationKind> {
        (value as? any SBJStructuralCollectionNode)?.sbjSupportedCollectionOperations ?? []
    }

    public static func applying(_ operation: SBJStructuralCollectionOperation, to value: Any) throws -> Any {
        guard let collection = value as? any SBJStructuralCollectionNode else {
            throw SBJStructuralCollectionOperationError.unsupportedOperation
        }
        guard collection.sbjSupportedCollectionOperations.contains(operation.kind) else {
            throw SBJStructuralCollectionOperationError.unsupportedOperation
        }
        return try collection.sbjApplyingCollectionOperation(operation)
    }
}

extension Array: SBJStructuralCollectionNode {
    public func sbjCreateCollectionElement() -> Any? {
        SBJCollectionElementCreation.create(existing: self) as Element?
    }

    public var sbjSupportedCollectionOperations: Set<SBJCollectionOperationKind> {
        [.append, .insert, .remove, .replace, .move, .duplicate, .clear]
    }

    public func sbjParseCollectionScalar(_ text: String, role: SBJCollectionScalarRole) throws -> Any {
        return try SBJCollectionScalar.parse(text, as: Element.self)
    }

    public func sbjApplyingCollectionOperation(_ operation: SBJStructuralCollectionOperation) throws -> Any {
        var copy = self
        switch operation {
        case .append(let value):
            guard let value = value as? Element else { throw SBJStructuralCollectionOperationError.typeMismatch }
            copy.append(value)
        case .insert(let value, let index):
            guard let value = value as? Element else { throw SBJStructuralCollectionOperationError.typeMismatch }
            guard index >= 0 && index <= count else { throw SBJStructuralCollectionOperationError.invalidIndex }
            copy.insert(value, at: index)
        case .remove(let index):
            guard indices.contains(index) else { throw SBJStructuralCollectionOperationError.invalidIndex }
            copy.remove(at: index)
        case .removeElement(let location):
            let index = try Self.sbjIndex(from: location, count: count)
            copy.remove(at: index)
        case .replace(let index, let value):
            guard indices.contains(index) else { throw SBJStructuralCollectionOperationError.invalidIndex }
            guard let value = value as? Element else { throw SBJStructuralCollectionOperationError.typeMismatch }
            copy[index] = value
        case .replaceElement(let location, let rawValue):
            let index = try Self.sbjIndex(from: location, count: count)
            guard let value = rawValue as? Element else { throw SBJStructuralCollectionOperationError.typeMismatch }
            copy[index] = value
        case .move(let from, let to):
            guard indices.contains(from), indices.contains(to) else { throw SBJStructuralCollectionOperationError.invalidIndex }
            let element = copy.remove(at: from)
            copy.insert(element, at: to)
        case .moveElement(let location, let to):
            let from = try Self.sbjIndex(from: location, count: count)
            guard indices.contains(to) else { throw SBJStructuralCollectionOperationError.invalidIndex }
            let element = copy.remove(at: from)
            copy.insert(element, at: to)
        case .duplicate(let index):
            guard indices.contains(index) else { throw SBJStructuralCollectionOperationError.invalidIndex }
            copy.insert(copy[index], at: index + 1)
        case .duplicateElement(let location):
            let index = try Self.sbjIndex(from: location, count: count)
            copy.insert(copy[index], at: index + 1)
        case .clear:
            copy.removeAll()
        default:
            throw SBJStructuralCollectionOperationError.unsupportedOperation
        }
        return copy
    }

    private static func sbjIndex(from location: String, count: Int) throws -> Int {
        guard location.hasPrefix("index:"),
              let index = Int(location.dropFirst("index:".count)),
              (0..<count).contains(index) else {
            throw SBJStructuralCollectionOperationError.invalidIndex
        }
        return index
    }
}

extension Dictionary: SBJStructuralCollectionNode {
    public var sbjSupportedCollectionOperations: Set<SBJCollectionOperationKind> {
        [.putKey, .insertKey, .replaceKey, .removeKey, .remove, .replace, .clear]
    }

    public func sbjParseCollectionScalar(_ text: String, role: SBJCollectionScalarRole) throws -> Any {
        switch role {
        case .key: return try SBJCollectionScalar.parse(text, as: Key.self)
        case .element: return try SBJCollectionScalar.parse(text, as: Value.self)
        }
    }

    public func sbjApplyingCollectionOperation(_ operation: SBJStructuralCollectionOperation) throws -> Any {
        var copy = self
        switch operation {
        case .put(let key, let value):
            guard let key = key as? Key, let value = value as? Value else {
                throw SBJStructuralCollectionOperationError.typeMismatch
            }
            copy[key] = value
        case .insertKey(let rawKey, let rawValue):
            guard let key = rawKey as? Key, let value = rawValue as? Value else {
                throw SBJStructuralCollectionOperationError.typeMismatch
            }
            guard copy[key] == nil else { throw SBJStructuralCollectionOperationError.collectionCollision }
            copy[key] = value
        case .replaceKey(let rawKey, let rawValue):
            guard let key = rawKey as? Key, let value = rawValue as? Value else {
                throw SBJStructuralCollectionOperationError.typeMismatch
            }
            guard copy[key] != nil else { throw SBJStructuralCollectionOperationError.missingElement }
            copy[key] = value
        case .removeElement(let location):
            guard let key = copy.keys.first(where: { "key:\(String(reflecting: $0))" == location }) else {
                throw SBJStructuralCollectionOperationError.missingElement
            }
            copy.removeValue(forKey: key)
        case .replaceElement(let location, let rawValue):
            guard let key = copy.keys.first(where: { "key:\(String(reflecting: $0))" == location }) else {
                throw SBJStructuralCollectionOperationError.missingElement
            }
            guard let value = rawValue as? Value else { throw SBJStructuralCollectionOperationError.typeMismatch }
            copy[key] = value
        case .removeKey(let rawKey):
            guard let key = rawKey as? Key else { throw SBJStructuralCollectionOperationError.typeMismatch }
            guard copy.removeValue(forKey: key) != nil else { throw SBJStructuralCollectionOperationError.missingElement }
        case .clear:
            copy.removeAll()
        default:
            throw SBJStructuralCollectionOperationError.unsupportedOperation
        }
        return copy
    }
}

extension Set: SBJStructuralCollectionNode {
    public func sbjCreateCollectionElement() -> Any? {
        SBJCollectionElementCreation.create(existing: Array(self)) as Element?
    }

    public var sbjSupportedCollectionOperations: Set<SBJCollectionOperationKind> {
        [.insertMember, .replaceMember, .removeMember, .remove, .replace, .clear]
    }

    public func sbjParseCollectionScalar(_ text: String, role: SBJCollectionScalarRole) throws -> Any {
        return try SBJCollectionScalar.parse(text, as: Element.self)
    }

    public func sbjApplyingCollectionOperation(_ operation: SBJStructuralCollectionOperation) throws -> Any {
        var copy = self
        switch operation {
        case .insertMember(let rawValue):
            guard let value = rawValue as? Element else { throw SBJStructuralCollectionOperationError.typeMismatch }
            guard copy.insert(value).inserted else { throw SBJStructuralCollectionOperationError.collectionCollision }
        case .replaceMember(let rawOld, let rawNew):
            guard let old = rawOld as? Element, let new = rawNew as? Element else {
                throw SBJStructuralCollectionOperationError.typeMismatch
            }
            guard copy.contains(old) else { throw SBJStructuralCollectionOperationError.missingElement }
            guard old == new || !copy.contains(new) else { throw SBJStructuralCollectionOperationError.collectionCollision }
            copy.remove(old)
            copy.insert(new)
        case .removeElement(let location):
            guard let element = copy.first(where: { Self.sbjLocation(for: $0) == location }) else {
                throw SBJStructuralCollectionOperationError.missingElement
            }
            copy.remove(element)
        case .replaceElement(let location, let rawValue):
            guard let old = copy.first(where: { Self.sbjLocation(for: $0) == location }) else {
                throw SBJStructuralCollectionOperationError.missingElement
            }
            guard let value = rawValue as? Element else { throw SBJStructuralCollectionOperationError.typeMismatch }
            guard old == value || !copy.contains(value) else { throw SBJStructuralCollectionOperationError.collectionCollision }
            copy.remove(old)
            copy.insert(value)
        case .removeMember(let rawValue):
            guard let value = rawValue as? Element else { throw SBJStructuralCollectionOperationError.typeMismatch }
            guard copy.remove(value) != nil else { throw SBJStructuralCollectionOperationError.missingElement }
        case .clear:
            copy.removeAll()
        default:
            throw SBJStructuralCollectionOperationError.unsupportedOperation
        }
        return copy
    }

    private static func sbjLocation(for element: Element) -> String {
        "item:\(String(reflecting: type(of: element))):\(String(reflecting: element))"
    }
}

extension Optional: SBJStructuralCollectionNode {
    public func sbjCreateCollectionElement() -> Any? {
        SBJCollectionElementCreation.create(existing: self.map { [$0] } ?? []) as Wrapped?
    }

    /// A zero-or-one collection supports the ordinary insertion, replacement,
    /// removal, and clear verbs, plus optional-specific convenience operations.
    public var sbjSupportedCollectionOperations: Set<SBJCollectionOperationKind> {
        [.append, .insert, .remove, .replace, .clear, .setOptional, .clearOptional]
    }

    public func sbjParseCollectionScalar(_ text: String, role: SBJCollectionScalarRole) throws -> Any {
        return try SBJCollectionScalar.parse(text, as: Wrapped.self)
    }

    public func sbjApplyingCollectionOperation(_ operation: SBJStructuralCollectionOperation) throws -> Any {
        switch operation {
        case .append(let rawValue):
            guard self == nil else { throw SBJStructuralCollectionOperationError.collectionCollision }
            guard let value = rawValue as? Wrapped else { throw SBJStructuralCollectionOperationError.typeMismatch }
            return Optional.some(value) as Any
        case .insert(let rawValue, let index):
            guard index == 0 else { throw SBJStructuralCollectionOperationError.invalidIndex }
            guard self == nil else { throw SBJStructuralCollectionOperationError.collectionCollision }
            guard let value = rawValue as? Wrapped else { throw SBJStructuralCollectionOperationError.typeMismatch }
            return Optional.some(value) as Any
        case .replace(let index, let rawValue):
            guard index == 0, self != nil else { throw SBJStructuralCollectionOperationError.invalidIndex }
            guard let value = rawValue as? Wrapped else { throw SBJStructuralCollectionOperationError.typeMismatch }
            return Optional.some(value) as Any
        case .remove(let index):
            guard index == 0, self != nil else { throw SBJStructuralCollectionOperationError.invalidIndex }
            return Optional<Wrapped>.none as Any
        case .setOptional(let rawValue):
            guard let value = rawValue as? Wrapped else { throw SBJStructuralCollectionOperationError.typeMismatch }
            return Optional.some(value) as Any
        case .clear, .clearOptional:
            return Optional<Wrapped>.none as Any
        default:
            throw SBJStructuralCollectionOperationError.unsupportedOperation
        }
    }
}
