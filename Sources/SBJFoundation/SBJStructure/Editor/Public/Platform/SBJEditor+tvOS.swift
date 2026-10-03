#if os(tvOS) || os(watchOS)
import Foundation

/// tvOS/watchOS retain the model metadata synthesized by `@SBJStructure`, but does
/// not provide the SwiftUI structured editor UI.
public protocol SBJSwiftUIEditable: SBJEditable {
    @MainActor
    static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] { get }
}

/// Metadata-only shell used by `@SBJStructure` on tvOS/watchOS. There is intentionally
/// no rendering API here: structured editing is not a tvOS/watchOS feature.
@MainActor
public struct SBJEditorPropertyDescriptor<Root: SBJStructured> {
    public let name: String
    public let editableField: SBJEditableField<Root>

    public init<Value: Codable>(
        name: String,
        _ keyPath: WritableKeyPath<Root, Value>
    ) {
        self.name = name
        self.editableField = SBJEditableField<Root>(name: name, keyPath)
    }

    public init<Value>(
        editorOnlyName name: String,
        _ keyPath: WritableKeyPath<Root, Value>
    ) {
        self.name = name
        self.editableField = SBJEditableField<Root>(editorOnlyName: name, keyPath)
    }
}

@MainActor
public struct SBJEditorAssociatedValue<Root> {
    public let name: String

    public init<Value: Codable>(
        name: String,
        get: @escaping (Root) -> Value,
        set: @escaping (inout Root, Value) -> Void
    ) {
        self.name = name
    }
}

@MainActor
public struct SBJEditorEnumCase<Root> {
    public let name: String
    public let associatedValues: [SBJEditorAssociatedValue<Root>]
    private let createValue: () -> Root?

    public init(
        name: String,
        matches: @escaping (Root) -> Bool,
        makeDefault: @escaping () -> Root?,
        associatedValues: [SBJEditorAssociatedValue<Root>] = []
    ) {
        self.name = name
        self.createValue = makeDefault
        self.associatedValues = associatedValues
    }

    public func makeDefaultValue() -> Root? { createValue() }
}

/// Associated-enum metadata remains available so `@SBJStructure` model
/// synthesis is source-compatible on tvOS/watchOS/watchOS, while the editor UI is omitted.
public protocol SBJEditableAssociatedEnum:
    Codable,
    HasContentCheckable,
    SBJDefaultValueCreatable,
    SBJStructuralComparable
{
    @MainActor
    static var sbjEditorEnumCases: [SBJEditorEnumCase<Self>] { get }
}

public extension SBJEditableAssociatedEnum {
    var hasContent: Bool { true }

    @available(*, deprecated, renamed: "sbjCreateDefaultValueIfPossible()")
    static func sbjCreateEditorValueIfPossible() -> Self? {
        sbjCreateDefaultValueIfPossible()
    }

    @available(*, deprecated, message: "Use sbjCreateDefaultValueIfPossible() and handle an unavailable default explicitly.")
    static func sbjCreateEditorValue() -> Self {
        guard let value = sbjCreateDefaultValueIfPossible() else {
            preconditionFailure("No enum case has creatable associated values")
        }
        return value
    }
}
#endif
