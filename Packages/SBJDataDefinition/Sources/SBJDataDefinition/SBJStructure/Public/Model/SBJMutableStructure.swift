import Foundation
import SBJLocalization

/// UI-independent description of a structured value whose writable properties
/// can be consumed by editors or other mutation tools.
///
/// Normally this conformance is synthesized by ``SBJStructure()``.
public protocol SBJMutableStructure: SBJStructured {
    static var sbjMutableProperties: [SBJMutableProperty<Self>] { get }
    /// Writable computed fields explicitly opted into presentation; not part of the stored schema.
    static var sbjPresentationProperties: [SBJMutableProperty<Self>] { get }
}

public extension SBJMutableStructure {
    static var sbjPresentationProperties: [SBJMutableProperty<Self>] { [] }
}

/// A type-preserving consumer of a writable structural property.
///
/// Each visit opens the original property type through the generic witness
/// captured when the descriptor was created. Consumers do not need to guess
/// types from names or dynamically cast key paths. Only stored Codable
/// properties participate; editor-only computed properties are not schema.
/// Visits a presentation-only writable field while preserving its concrete value type.
/// This is distinct from schema visitation because computed presentation fields
/// need not be Codable and never participate in structural validation.
public protocol SBJTypedPresentationPropertyVisitor<Root>: AnyObject {
    associatedtype Root: SBJStructured
    func visit<Value>(_ keyPath: WritableKeyPath<Root, Value>, name: String)
}

public protocol SBJTypedStructuralPropertyVisitor<Root>: AnyObject {
    associatedtype Root: SBJStructured

    func visit<Value: Codable>(
        _ keyPath: WritableKeyPath<Root, Value>,
        metadata: SBJPropertyMetadata<Root>?
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
    public let structuralMetadata: SBJPropertyMetadata<Root>?
    public let participatesInStructuralValidation: Bool

    private let dispatchTypedProperty: ((any SBJTypedStructuralPropertyVisitor<Root>) -> Void)?
    private let dispatchPresentationProperty: ((any SBJTypedPresentationPropertyVisitor<Root>) -> Void)?
    private let getValue: (Root) -> Any
    private let assignValue: (inout Root, Any) -> Bool
    private let matchesSearchValue: (Root, String) -> Bool
    private let hasChangedValue: (Root, Root?) -> Bool
    private let hasContentValue: (Root) -> Bool?
    private let containsEmptyContentValue: (Root, (Any.Type) -> Bool) -> Bool
    private let validationErrorValue: (Root) -> SBJValidationError?

    public init<Value: Codable>(
        name: String,
        _ keyPath: WritableKeyPath<Root, Value>
    ) {
        self.name = name
        self.valueType = Value.self
        self.keyPath = keyPath
        let structuralMetadata = Root.propertyMetadata(for: keyPath)
        self.structuralMetadata = structuralMetadata
        self.participatesInStructuralValidation = true
        self.dispatchTypedProperty = { visitor in
            visitor.visit(keyPath, metadata: structuralMetadata)
        }
        self.dispatchPresentationProperty = nil
        self.getValue = { $0[keyPath: keyPath] }
        self.assignValue = { root, value in
            guard let typed = value as? Value else { return false }
            root[keyPath: keyPath] = typed
            return true
        }
        self.matchesSearchValue = { root, query in
            sbjPredicated(label: name, value: root[keyPath: keyPath], search: query)
        }
        self.hasChangedValue = { root, originalRoot in
            guard let originalRoot else { return true }
            if let structuralMetadata {
                return !structuralMetadata.structurallyEquals(in: root, originalRoot)
            }
            return !SBJStructuralCompare.equals(
                root[keyPath: keyPath],
                originalRoot[keyPath: keyPath]
            )
        }
        self.hasContentValue = { root in
            (root[keyPath: keyPath] as? any HasContentCheckable)?.hasContent
        }
        self.containsEmptyContentValue = { root, treatingAsLeaf in
            SBJContentCheck.containsEmptyContent(
                root[keyPath: keyPath],
                treatingAsLeaf: treatingAsLeaf
            )
        }
        self.validationErrorValue = { root in
            SBJInvariantCheck.validationError(
                root[keyPath: keyPath],
                at: SBJValidationKeyPath(keyPath)
            )
        }
    }

    /// Creates a writable field intentionally outside `Root`'s structural
    /// metadata. This is still editor-independent: an alternative editor may
    /// choose whether and how to render the value.
    public init<Value>(
        nonStructuralName name: String,
        _ keyPath: WritableKeyPath<Root, Value>
    ) {
        self.name = name
        self.valueType = Value.self
        self.keyPath = keyPath
        self.structuralMetadata = nil
        self.participatesInStructuralValidation = false
        self.dispatchTypedProperty = nil
        self.dispatchPresentationProperty = { visitor in
            visitor.visit(keyPath, name: name)
        }
        self.getValue = { $0[keyPath: keyPath] }
        self.assignValue = { root, value in
            guard let typed = value as? Value else { return false }
            root[keyPath: keyPath] = typed
            return true
        }
        self.matchesSearchValue = { _, query in sbjPredicated(name, search: query) }
        self.hasChangedValue = { _, _ in false }
        self.hasContentValue = { _ in nil }
        self.containsEmptyContentValue = { _, _ in false }
        self.validationErrorValue = { _ in nil }
    }

    /// Dispatches to a consumer with the property's actual generic Codable type.
    /// Returns `false` for fields outside the structural schema.
    @discardableResult
    public func visitTypedProperty(
        with visitor: any SBJTypedStructuralPropertyVisitor<Root>
    ) -> Bool {
        guard let dispatchTypedProperty else { return false }
        dispatchTypedProperty(visitor)
        return true
    }

    /// Opens a presentation-only property with its actual generic Swift type.
    @discardableResult
    public func visitTypedPresentationProperty(
        with visitor: any SBJTypedPresentationPropertyVisitor<Root>
    ) -> Bool {
        guard let dispatchPresentationProperty else { return false }
        dispatchPresentationProperty(visitor)
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
