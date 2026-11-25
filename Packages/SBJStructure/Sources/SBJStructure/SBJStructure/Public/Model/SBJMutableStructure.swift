import Foundation
import SBJLocalization

/// UI-independent description of a structured value whose writable properties
/// can be consumed by editors or other mutation tools.
///
/// Normally this conformance is synthesized by ``SBJStructure()``.
public protocol SBJMutableStructure: SBJStructured, SBJStructuralMutationNode {
    static var sbjMutableProperties: [SBJMutableProperty<Self>] { get }
}

public extension SBJMutableStructure {
    static var sbjMutableProperties: [SBJMutableProperty<Self>] { sbjProperties.compactMap { $0.mutableProperty() } }

    static func sbjConstructRuntime(fromJSON data: Data) throws -> Self {
        try SBJRuntimeConstruction.construct(Self.self, fromJSON: data)
    }
}

/// Type-preserving writable property visitor.
public protocol SBJTypedStructuralPropertyVisitor<Root>: AnyObject {
    associatedtype Root: SBJStructured

    func visit<Value>(
        _ keyPath: WritableKeyPath<Root, Value>,
        metadata: SBJPropertyMetadata<Root>
    )
}

/// UI-independent, type-erased description of one writable property on `Root`.
///
/// The descriptor intentionally contains no SwiftUI concepts. It exposes the
/// writable key path and editor-independent behaviors so alternative editors can
/// reuse the same generated model description.
public struct SBJMutableProperty<Root: SBJStructured> {
    public let name: String
    public let valueType: Any.Type
    public let keyPath: PartialKeyPath<Root>
    public let structuralMetadata: SBJPropertyMetadata<Root>

    private let dispatchTypedProperty: (any SBJTypedStructuralPropertyVisitor<Root>) -> Void
    private let getValue: (Root) -> Any
    private let assignValue: (inout Root, Any) -> Bool
    private let matchesSearchValue: (Root, String) -> Bool
    private let hasChangedValue: (Root, Root?) -> Bool
    private let hasContentValue: (Root) -> Bool?
    private let containsEmptyContentValue: (Root, (Any.Type) -> Bool) -> Bool
    private let validationErrorValue: (Root) -> SBJValidationError?

    // Only the canonical descriptor can manufacture the writable capability.
    init<Value>(metadata: SBJPropertyMetadata<Root>, keyPath: WritableKeyPath<Root, Value>) {
        let name = metadata.displayName
        self.name = name
        self.valueType = Value.self
        self.keyPath = keyPath
        let structuralMetadata = metadata
        self.structuralMetadata = structuralMetadata
        self.dispatchTypedProperty = { visitor in
            visitor.visit(keyPath, metadata: structuralMetadata)
        }
        self.getValue = { $0[keyPath: keyPath] }
        self.assignValue = { root, value in
            guard let typed = value as? Value else { return false }
            root[keyPath: keyPath] = typed
            return true
        }
        self.matchesSearchValue = { root, query in
            structuralMetadata.matchesSearch(in: root, query: query)
        }
        self.hasChangedValue = { root, originalRoot in
            guard let originalRoot else { return true }
            return !structuralMetadata.structurallyEquals(in: root, originalRoot)
        }
        self.hasContentValue = { root in
            structuralMetadata.hasContent(in: root)
        }
        self.containsEmptyContentValue = { root, treatingAsLeaf in
            structuralMetadata.containsEmptyContent(
                in: root,
                treatingAsLeaf: treatingAsLeaf
            )
        }
        self.validationErrorValue = { root in structuralMetadata.validationError(in: root) }
    }

    /// Dispatches to a consumer with the actual Swift value type.
    @discardableResult
    public func visitTypedProperty(with visitor: any SBJTypedStructuralPropertyVisitor<Root>) -> Bool {
        dispatchTypedProperty(visitor)
        return true
    }

    public func value(in root: Root) -> Any { getValue(root) }

    /// Accesses a property with its declared concrete type. A mismatch returns
    /// `nil` rather than permitting an unchecked cast. The callback preserves
    /// the Swift type and may be used without SwiftUI or an editor registry.
    public func withTypedValue<Value, Result>(
        in root: Root,
        as type: Value.Type,
        _ body: (Value) throws -> Result
    ) rethrows -> Result? {
        guard valueType == Value.self, let value = getValue(root) as? Value else { return nil }
        return try body(value)
    }

    /// Exposes the original writable key path only to consumers expecting its
    /// exact Swift value type. No String-based type lookup is involved.
    public func withWritableKeyPath<Value, Result>(
        as type: Value.Type,
        _ body: (WritableKeyPath<Root, Value>) throws -> Result
    ) rethrows -> Result? {
        guard valueType == Value.self,
              let typed = keyPath as? WritableKeyPath<Root, Value> else { return nil }
        return try body(typed)
    }

    /// Attempts to assign a type-erased value. Returns `false` if its runtime
    /// type does not match this field's declared Swift type.
    @discardableResult
    public func setValue(_ value: Any, in root: inout Root) -> Bool {
        assignValue(&root, value)
    }

    public func matchesSearch(in root: Root, query: String) -> Bool {
        matchesSearchValue(root, query)
    }

    public func hasChanged(in root: Root, from originalRoot: Root?) -> Bool {
        hasChangedValue(root, originalRoot)
    }

    public func hasContent(in root: Root) -> Bool? {
        hasContentValue(root)
    }

    public func containsEmptyContent(
        in root: Root,
        treatingAsLeaf: (Any.Type) -> Bool = { _ in false }
    ) -> Bool {
        containsEmptyContentValue(root, treatingAsLeaf)
    }

    public func validationError(in root: Root) -> SBJValidationError? {
        validationErrorValue(root)
    }
}
