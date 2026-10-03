#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Metadata for one associated value belonging to an enum case synthesized by
/// ``SBJStructure()``.
@MainActor
public struct SBJEditorAssociatedValue<Root> {
    public let name: String
    private let makeView: (Binding<Root>, Root?, SBJEditorRegistry, SBJEditorFocusRequest?, SBJEditTraversalContext) -> AnyView
    private let collectIssues: (Root, [String], SBJEditorRegistry) -> [SBJEditorCapabilityIssue]
    private let matchesSearch: (Root, String, SBJEditorRegistry) -> Bool
    private let hasChanged: (Root, Root?) -> Bool
    private let hasContent: (Root) -> Bool?
    private let containsEmptyContent: (Root, SBJEditorRegistry) -> Bool
    private let isInvalid: (Root) -> Bool

    public init<Value: Codable>(
        name: String,
        get: @escaping (Root) -> Value,
        set: @escaping (inout Root, Value) -> Void
    ) {
        self.name = name
        self.makeView = { root, originalRoot, registry, focusRequest, context in
            let binding = Binding<Value>(
                get: { get(root.wrappedValue) },
                set: { newValue in
                    var current = root.wrappedValue
                    set(&current, newValue)
                    root.wrappedValue = current
                }
            )
            let originalValue = originalRoot.map(get)
            return SBJValueEditor.makeView(
                label: name,
                value: binding,
                originalValue: originalValue.map { SBJEditorOriginalValue($0) },
                registry: registry,
                focusRequest: focusRequest,
                context: context
            )
        }
        self.collectIssues = { root, path, registry in
            SBJValueEditor.collectIssues(
                value: get(root),
                path: path + [name],
                registry: registry
            )
        }
        self.matchesSearch = { root, query, _ in
            sbjPredicated(
                label: name,
                value: get(root),
                search: query
            )
        }
        self.hasChanged = { root, originalRoot in
            guard let originalRoot else { return true }
            return !SBJStructuralCompare.equals(get(root), get(originalRoot))
        }
        self.hasContent = { root in
            (get(root) as? any HasContentCheckable)?.hasContent
        }
        self.containsEmptyContent = { root, registry in
            SBJContentCheck.containsEmptyContent(
                get(root),
                treatingAsLeaf: { registry.hasCustomEditor($0) }
            )
        }
        self.isInvalid = { root in
            SBJInvariantCheck.validationError(
                get(root),
                at: SBJValidationKeyPath(\Value.self)
            ) != nil
        }
    }

    func view(
        root: Binding<Root>,
        originalRoot: Root?,
        registry: SBJEditorRegistry,
        focusRequest: SBJEditorFocusRequest?,
        context: SBJEditTraversalContext
    ) -> AnyView {
        let changed = hasChanged(root.wrappedValue, originalRoot)
        let contentState = hasContent(root.wrappedValue)
        let invalid = isInvalid(root.wrappedValue)
        return AnyView(
            SBJEditorFilteredView(
                content: {
                    AnyView(
                        makeView(root, originalRoot, registry, focusRequest, context)
                            .environment(\.sbjEditorIsChanged, changed)
                            .environment(\.sbjEditorHasContent, contentState)
                            .environment(\.sbjEditorIsInvalid, invalid)
                    )
                },
                isChanged: changed,
                matchesSearch: { query in matchesSearch(root.wrappedValue, query, registry) },
                containsEmptyContent: { containsEmptyContent(root.wrappedValue, registry) },
                navigationPath: context.navigationPath
            )
            .id(context.itemIdentifier)
        )
    }

    func containsEmptyContent(
        root: Root,
        registry: SBJEditorRegistry
    ) -> Bool {
        containsEmptyContent(root, registry)
    }

    func issues(
        root: Root,
        path: [String],
        registry: SBJEditorRegistry
    ) -> [SBJEditorCapabilityIssue] {
        collectIssues(root, path, registry)
    }
}

/// Metadata for one case of an associated-value enum synthesized by
/// ``SBJStructure()``.
@MainActor
public struct SBJEditorEnumCase<Root> {
    public let name: String
    public let associatedValues: [SBJEditorAssociatedValue<Root>]
    private let matchesValue: (Root) -> Bool
    private let createValue: () -> Root?

    public init(
        name: String,
        matches: @escaping (Root) -> Bool,
        makeDefault: @escaping () -> Root?,
        associatedValues: [SBJEditorAssociatedValue<Root>] = []
    ) {
        self.name = name
        self.matchesValue = matches
        self.createValue = makeDefault
        self.associatedValues = associatedValues
    }

    public func matches(_ value: Root) -> Bool {
        matchesValue(value)
    }

    public func makeDefaultValue() -> Root? {
        createValue()
    }

    var canCreate: Bool {
        createValue() != nil
    }

    func issues(
        value: Root,
        path: [String],
        registry: SBJEditorRegistry
    ) -> [SBJEditorCapabilityIssue] {
        guard matches(value) else { return [] }
        return associatedValues.flatMap { field in
            field.issues(root: value, path: path, registry: registry)
        }
    }
}

/// An enum whose cases and associated values can be edited recursively.
///
/// This conformance is normally synthesized by ``SBJStructure()`` when the
/// macro is attached to an enum declaration.
public protocol SBJEditableAssociatedEnum: Codable, HasContentCheckable, SBJDefaultValueCreatable, SBJStructuralComparable {
    @MainActor
    static var sbjEditorEnumCases: [SBJEditorEnumCase<Self>] { get }

}

public extension SBJEditableAssociatedEnum {
    /// Associated-value enums are atomic selections by default. A domain type
    /// can override this when one of its cases represents an empty/default value.
    var hasContent: Bool { true }

    /// Compatibility alias for the former editor-owned creation API.
    @available(*, deprecated, renamed: "sbjCreateDefaultValueIfPossible()")
    static func sbjCreateEditorValueIfPossible() -> Self? {
        sbjCreateDefaultValueIfPossible()
    }

    /// Compatibility convenience for callers that require creation to succeed.
    @available(*, deprecated, message: "Use sbjCreateDefaultValueIfPossible() and handle an unavailable default explicitly.")
    static func sbjCreateEditorValue() -> Self {
        guard let value = sbjCreateDefaultValueIfPossible() else {
            preconditionFailure("No enum case has creatable associated values")
        }
        return value
    }

    @MainActor
    internal static func _sbjMakeAssociatedEnumEditor(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue? = nil,
        registry: SBJEditorRegistry,
        focusRequest: SBJEditorFocusRequest? = nil,
        labelIsUnknown: Bool = false,
        context: SBJEditTraversalContext = .root
    ) -> AnyView {
        let typedBinding = binding.binding(as: Self.self)
        return AnyView(
            SBJAssociatedEnumEditor(
                label: label,
                value: typedBinding,
                originalValue: originalValue.map { $0.value(as: Self.self) },
                registry: registry,
                focusRequest: focusRequest,
                labelIsUnknown: labelIsUnknown,
                context: context
            )
        )
    }

    @MainActor
    internal static func _sbjCollectAssociatedEnumIssues(
        value: Any,
        path: [String],
        registry: SBJEditorRegistry
    ) -> [SBJEditorCapabilityIssue] {
        guard let typed = value as? Self,
              let selected = sbjEditorEnumCases.first(where: { $0.matches(typed) }) else {
            return [
                SBJEditorCapabilityIssue(
                    path: path.joined(separator: " • "),
                    typeName: String(describing: Self.self),
                    valueDescription: SBJValueDescription.describe(value)
                )
            ]
        }
        return selected.issues(value: typed, path: path, registry: registry)
    }
}
#endif
