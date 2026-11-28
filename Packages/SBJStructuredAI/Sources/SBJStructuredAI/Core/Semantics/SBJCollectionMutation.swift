import Foundation
import SBJStructure

/// A native tool request, independent of the model provider. Positions are one-based.
struct SBJCollectionMutationRequest: Sendable {
    let keyPath: [String]
    let operation: String
    var member: String? = nil
    var position: Int? = nil
    var value: String? = nil
}

enum SBJCollectionMutation {
    enum Result {
        case count(Int)
        case proposal(SBJLeafMutation.Proposal)
    }

    static func prepare<Root>(_ root: Root, snapshot: SBJSemanticReadSnapshot,
                              request: SBJCollectionMutationRequest) throws -> Result {
        let location = try snapshot.resolveCollection(request.keyPath)
        guard let structured = root as? any SBJStructured else { throw SBJStructuralCollectionOperationError.unsupportedOperation }
        let matches = SBJStructuralTraversal.descendants(in: structured, options: snapshot.traversalOptions).filter { $0.locationPath == location }
        guard matches.count == 1, let occurrence = matches.first,
              let outer = occurrence.value as? any SBJAICollectionAdapter else {
            throw SBJStructuralCollectionOperationError.unsupportedOperation
        }
        let verb = request.operation.lowercased()
        let optional = occurrence.value as? any SBJAIOptionalCollection
        // An optional collection has two operations on the wrapper itself: set
        // and clearOptional. Ordinary verbs address the present inner collection.
        // Count retains the existing semantic optional-presence convention;
        // countMembers explicitly counts the contained collection.
        let addressesContents = optional?.aiWrapsCollection == true &&
            !["set", "setoptional", "clearoptional", "count"].contains(verb)
        let adapter: any SBJAICollectionAdapter
        if addressesContents {
            guard let inner = optional?.aiWrappedCollection else {
                throw SBJLeafMutationError.resolution(SBJSemanticReadResult.status(.unset).promptText)
            }
            adapter = inner
        } else { adapter = outer }
        let children = adapter.aiChildren
        if verb == "count" || verb == "countmembers" { return .count(children.count) }
        guard occurrence.isWritableProperty else { throw SBJLeafMutationError.immutable }
        let supported = adapter.sbjSupportedCollectionOperations
        func member() throws -> SBJStructuralChild {
            guard let key = request.member else { throw SBJStructuralCollectionOperationError.missingElement }
            if supported.contains(.setOptional) {
                guard key == "@1", let child = children.first else { throw SBJStructuralCollectionOperationError.missingElement }
                return child
            }
            let token = try snapshot.resolveCollectionMember(request.keyPath, member: key, parent: location)
            let matches = children.filter { $0.location == token }
            guard matches.count == 1, let child = matches.first else { throw SBJStructuralCollectionOperationError.missingElement }
            return child
        }
        func position() throws -> Int {
            guard let ordinal = request.position, ordinal > 0 else { throw SBJStructuralCollectionOperationError.invalidIndex }
            return ordinal - 1
        }
        func newValue() throws -> Any {
            if let text = request.value { return try adapter.aiElement(text) }
            guard let value = adapter.aiCreateElement() else { throw SBJStructuralCollectionOperationError.typeMismatch }
            return value
        }
        func newKey() throws -> Any {
            guard let key = request.member else { throw SBJStructuralCollectionOperationError.missingElement }
            return try adapter.aiKey(key)
        }
        // Reject extraneous selectors rather than accidentally clearing a whole
        // collection when the request supplied an individual member.
        if ["clear", "clearoptional"].contains(verb),
           request.member != nil || request.position != nil || request.value != nil {
            throw SBJStructuralCollectionOperationError.unsupportedOperation
        }
        let operation: SBJStructuralCollectionOperation
        switch verb {
        case "add", "append", "new":
            if supported.contains(.insertKey) { operation = .insertKey(key: try newKey(), value: try newValue()) }
            else if supported.contains(.insertMember) { operation = .insertMember(try newValue()) }
            else { operation = .append(try newValue()) }
        case "insert":
            if supported.contains(.insertKey) { operation = .insertKey(key: try newKey(), value: try newValue()) }
            else if supported.contains(.insertMember) { operation = .insertMember(try newValue()) }
            else { operation = .insert(try newValue(), at: try position()) }
        case "remove", "delete", "removekey", "removemember":
            let selected = try member()
            operation = supported.contains(.setOptional) ? .remove(at: 0) : .removeElement(atLocation: selected.location)
        case "replace", "replacekey", "replacemember":
            let selected = try member()
            let replacement = try newValue()
            operation = supported.contains(.setOptional) ? .replace(at: 0, with: replacement) : .replaceElement(atLocation: selected.location, with: replacement)
        case "move": operation = .moveElement(atLocation: try member().location, to: try position())
        case "duplicate": operation = .duplicateElement(atLocation: try member().location)
        case "clear": operation = .clear
        case "clearoptional": operation = .clearOptional
        case "put", "putkey": operation = .put(key: try newKey(), value: try newValue())
        case "insertkey": operation = .insertKey(key: try newKey(), value: try newValue())
        case "insertmember": operation = .insertMember(try newValue())
        case "set", "setoptional": operation = .setOptional(try newValue())
        default: throw SBJStructuralCollectionOperationError.unsupportedOperation
        }
        let changed = try SBJStructuralCollectionMutation.applying(operation, to: adapter)
        guard let updated = changed as? any SBJAICollectionAdapter else { throw SBJStructuralCollectionOperationError.typeMismatch }
        let replacement: Any
        if addressesContents, let optional { replacement = try optional.aiRewrap(changed) }
        else { replacement = changed }
        // Show actual old/new member contents, not just a count (moves and replacements may preserve count).
        return .proposal(.init(location: location, replacement: replacement,
            change: .init(field: occurrence.displayPath.joined(separator: " / ") + " — " + operation.kind.rawValue,
                          oldValue: preview(children, options: snapshot.traversalOptions), proposedValue: preview(updated.aiChildren, options: snapshot.traversalOptions))))
    }

    private static func preview(_ children: [SBJStructuralChild], options: SBJTraversalOptions) -> String {
        guard !children.isEmpty else { return "Empty (0)" }
        return "\(children.count) items:\n" + children.enumerated().map { index, child in
            let key = child.dictionaryKey.map { String(describing: $0) } ?? String(index + 1)
            return "\(key): \(previewValue(child.value, options: options))"
        }.joined(separator: "\n")
    }

    private static func previewValue(_ value: Any, options: SBJTraversalOptions) -> String {
        if let text = value as? String, Swift.type(of: value) == String.self { return String(reflecting: text) }
        if let scalar = SBJSemanticScalarReading.value(value, type: Swift.type(of: value)) {
            return scalar.label ?? SBJSemanticReadResult.render(scalar)
        }
        if let structure = value as? any SBJStructured {
            return SBJStructuralTraversal.descendants(in: structure, options: options).compactMap { occurrence -> String? in
                guard let scalar = SBJSemanticScalarReading.value(occurrence.value, type: occurrence.valueType) else { return nil }
                return occurrence.displayPath.joined(separator: " / ") + ": " + (scalar.label ?? SBJSemanticReadResult.render(scalar))
            }.joined(separator: "; ")
        }
        if let container = value as? any SBJStructuralValueContainer {
            let parts = container.sbjStructuralChildren(itemTitleKey: nil, itemIdentifierKey: nil)
            return parts.isEmpty ? "Empty" : parts.map { previewValue($0.value, options: options) }.joined(separator: ", ")
        }
        return String(describing: Swift.type(of: value))
    }
}

/// Typed adapters bridge collection creation and scalar conversion, never JSON reconstruction.
private protocol SBJAICollectionAdapter: SBJStructuralCollectionNode, SBJStructuralValueContainer {
    func aiElement(_ text: String) throws -> Any
    func aiKey(_ text: String) throws -> Any
    func aiCreateElement() -> Any?
}
private extension SBJAICollectionAdapter {
    var aiChildren: [SBJStructuralChild] { sbjStructuralChildren(itemTitleKey: nil, itemIdentifierKey: nil) }
    func aiKey(_ text: String) throws -> Any { throw SBJStructuralCollectionOperationError.unsupportedOperation }
    func aiCreateElement() -> Any? { sbjCreateCollectionElement() }
}
private protocol SBJAIOptionalScalar {
    static func aiParseWrapped(_ text: String) throws -> Any
}
extension Optional: SBJAIOptionalScalar {
    fileprivate static func aiParseWrapped(_ text: String) throws -> Any {
        guard let wrapped = try aiScalar(text, as: Wrapped.self) as? Wrapped else { throw SBJStructuralCollectionOperationError.typeMismatch }
        return Optional.some(wrapped) as Any
    }
}
private func aiScalar<T>(_ text: String, as type: T.Type) throws -> Any {
    if let optional = type as? any SBJAIOptionalScalar.Type { return try optional.aiParseWrapped(text) }
    guard let sample = SBJDefaultValue.value(for: type) else { throw SBJStructuralCollectionOperationError.typeMismatch }
    return try SBJLeafMutation.convert(text, matching: sample)
}
extension Array: SBJAICollectionAdapter {
    fileprivate func aiElement(_ text: String) throws -> Any { try aiScalar(text, as: Element.self) }
}
extension Set: SBJAICollectionAdapter {
    fileprivate func aiElement(_ text: String) throws -> Any { try aiScalar(text, as: Element.self) }
}
extension Dictionary: SBJAICollectionAdapter {
    fileprivate func aiElement(_ text: String) throws -> Any { try aiScalar(text, as: Value.self) }
    fileprivate func aiKey(_ text: String) throws -> Any { try aiScalar(text, as: Key.self) }
    fileprivate func aiCreateElement() -> Any? { SBJCollectionElementCreation.create(existing: Array(values)) as Value? }
}
private protocol SBJAIOptionalCollection {
    var aiWrapsCollection: Bool { get }
    var aiWrappedCollection: (any SBJAICollectionAdapter)? { get }
    func aiRewrap(_ value: Any) throws -> Any
}
private protocol SBJAIEmptyCollection {
    static func aiEmpty() -> Any
}
extension Array: SBJAIEmptyCollection { fileprivate static func aiEmpty() -> Any { Self() } }
extension Set: SBJAIEmptyCollection { fileprivate static func aiEmpty() -> Any { Self() } }
extension Dictionary: SBJAIEmptyCollection { fileprivate static func aiEmpty() -> Any { Self() } }
extension Optional: SBJAICollectionAdapter, SBJAIOptionalCollection {
    fileprivate func aiElement(_ text: String) throws -> Any { try aiScalar(text, as: Wrapped.self) }
    fileprivate func aiCreateElement() -> Any? {
        if let factory = Wrapped.self as? any SBJAIEmptyCollection.Type { return factory.aiEmpty() }
        return sbjCreateCollectionElement()
    }
    fileprivate var aiWrapsCollection: Bool { Wrapped.self is any SBJAIEmptyCollection.Type }
    fileprivate var aiWrappedCollection: (any SBJAICollectionAdapter)? {
        guard let wrapped = self else { return nil }
        return wrapped as? any SBJAICollectionAdapter
    }
    fileprivate func aiRewrap(_ value: Any) throws -> Any {
        guard let wrapped = value as? Wrapped else { throw SBJStructuralCollectionOperationError.typeMismatch }
        return Optional.some(wrapped) as Any
    }
}
