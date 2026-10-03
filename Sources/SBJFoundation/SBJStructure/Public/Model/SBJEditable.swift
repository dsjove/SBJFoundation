import Foundation

/// UI-independent description of a structured value whose writable properties
/// can be consumed by editors or other mutation tools.
///
/// Normally this conformance is synthesized by ``SBJStructure()``.
public protocol SBJEditable: SBJStructured {
    static var sbjEditableFields: [SBJEditableField<Self>] { get }
}

public extension SBJEditable {
    /// Human-readable default name used by editors and other presentation tools.
    static var sbjEditorTypeName: String {
        String(describing: Self.self).uncamelCased
    }
}

/// UI-independent, type-erased description of one writable property on `Root`.
///
/// The descriptor intentionally contains no SwiftUI concepts. It exposes the
/// writable key path and editor-independent behaviors so alternative editors can
/// reuse the same generated model description.
public struct SBJEditableField<Root: SBJStructured> {
    public let name: String
    public let valueType: Any.Type
    public let keyPath: PartialKeyPath<Root>
    public let structuralMetadata: SBJPropertyMetadata<Root>?
    public let participatesInStructuralValidation: Bool

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
        editorOnlyName name: String,
        _ keyPath: WritableKeyPath<Root, Value>
    ) {
        self.name = name
        self.valueType = Value.self
        self.keyPath = keyPath
        self.structuralMetadata = nil
        self.participatesInStructuralValidation = false
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

    public func value(in root: Root) -> Any { getValue(root) }

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
