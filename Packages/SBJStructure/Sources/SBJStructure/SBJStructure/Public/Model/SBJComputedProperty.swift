import Foundation
import SBJLocalization

/// Opens the typed key path of a computed property for a consumer.
public protocol SBJTypedComputedPropertyVisitor<Root>: AnyObject {
    associatedtype Root: SBJStructured
    func visit<Value>(_ keyPath: KeyPath<Root, Value>, name: String, showInEditor: Bool)
}

/// A non-serialized computed value exposed for semantic discovery.
/// The original typed key path is retained, rather than a string-based getter.
public struct SBJComputedProperty<Root: SBJStructured> {
    public let sourceName: String
    public let displayName: String
    public let keyPath: PartialKeyPath<Root>
    public let valueType: Any.Type
    public let info: SBJNomenclature?
    public let showInEditor: Bool

    private let readValue: (Root) -> Any
    private let visitTyped: (any SBJTypedComputedPropertyVisitor<Root>) -> Void

    public init<Value>(
        sourceName: String,
        displayName: String,
        keyPath: KeyPath<Root, Value>,
        info: SBJNomenclature? = nil,
        showInEditor: Bool = false
    ) {
        self.sourceName = sourceName
        let resolvedDisplayName = info?.nonEmptyTitle ?? displayName
        self.displayName = resolvedDisplayName
        self.keyPath = keyPath
        self.valueType = Value.self
        self.info = info
        self.showInEditor = showInEditor
        self.readValue = { $0[keyPath: keyPath] }
        self.visitTyped = { visitor in
            visitor.visit(keyPath, name: resolvedDisplayName, showInEditor: showInEditor)
        }
    }

    public func value(in root: Root) -> Any { readValue(root) }
    public func visitTypedProperty(with visitor: any SBJTypedComputedPropertyVisitor<Root>) {
        visitTyped(visitor)
    }
}
