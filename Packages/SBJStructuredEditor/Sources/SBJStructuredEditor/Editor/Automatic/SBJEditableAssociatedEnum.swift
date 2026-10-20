import SBJUIVocabulary
import SBJUnits
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
    private let makeTraversalNode: (Binding<Root>, Root?, SBJEditorRegistry, SBJEditTraversalContext) -> SBJEditorTraversalNode
    private let makeSnapshotNode: (Root, SBJEditTraversalContext) -> SBJEditorTraversalNode

    public init<Value: Codable>(
        name: String,
        get: @escaping (Root) -> Value,
        set: @escaping (inout Root, Value) -> Void
    ) {
        self.name = name
        self.makeTraversalNode = { root, originalRoot, registry, context in
            let binding = Binding<Value>(
                get: { get(root.wrappedValue) },
                set: { newValue in
                    var current = root.wrappedValue
                    set(&current, newValue)
                    root.wrappedValue = current
                }
            )
            return SBJEditorValueTraversal.boundNode(
                named: name, binding: binding, originalValue: originalRoot.map(get), context: context, registry: registry
            )
        }
        self.makeSnapshotNode = { root, context in
            SBJEditorValueTraversal.node(named: name, value: get(root), context: context)
        }
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

    func traversalNode(root: Root, context: SBJEditTraversalContext) -> SBJEditorTraversalNode {
        makeSnapshotNode(root, context)
    }

    func boundTraversalNode(
        root: Binding<Root>, originalRoot: Root? = nil, registry: SBJEditorRegistry,
        context: SBJEditTraversalContext
    ) -> SBJEditorTraversalNode {
        makeTraversalNode(root, originalRoot, registry, context)
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
        let rowContext = context.withBranch(context.branch.withStatus(
            .init(isChanged: changed, hasContent: contentState, isInvalid: invalid)
        ))
        return AnyView(
            SBJEditorFilteredView(
                content: {
                    AnyView(
                        makeView(root, originalRoot, registry, focusRequest, rowContext)
                    )
                },
                isChanged: changed,
                matchesSearch: { query in matchesSearch(root.wrappedValue, query, registry) },
                containsEmptyContent: { containsEmptyContent(root.wrappedValue, registry) },
                navigationPath: context.navigationPath,
                searchCriteria: context.branch.searchCriteria
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
    /// An enum case with associated values aggregates its payload like a struct.
    /// A case without payload is an atomic selection and always has content.
    var hasContent: Bool {
        let mirror = Mirror(reflecting: self)
        guard let payload = mirror.children.first?.value else { return true }
        return SBJContentCheck.hasContent(payload)
    }

    @MainActor
    internal static func _sbjAssociatedTraversalNodes(
        value: Any, context: SBJEditTraversalContext
    ) -> [SBJEditorTraversalNode] {
        guard let value = value as? Self,
              let selected = sbjEditorEnumCases.first(where: { $0.matches(value) }) else { return [] }
        return selected.associatedValues.enumerated().map { offset, field in
            let childContext = SBJEditTraversalContext(
                treeLevel: context.treeLevel + 1,
                itemIdentifier: context.itemIdentifier
                    .appending("case:\(selected.name)")
                    .appending("property:\(field.name)"),
                indexPath: context.indexPath.appending("field:\(offset)"),
                navigationPath: context.navigationPath + [field.name],
                branch: context.branch.child
            )
            return field.traversalNode(root: value, context: childContext)
        }
    }

    @MainActor
    internal static func _sbjBoundAssociatedTraversalNodes(
        binding: SBJAnyBinding, originalValue: Any? = nil, registry: SBJEditorRegistry,
        context: SBJEditTraversalContext
    ) -> [SBJEditorTraversalNode] {
        let root = binding.binding(as: Self.self)
        guard let selected = sbjEditorEnumCases.first(where: { $0.matches(root.wrappedValue) }) else {
            return []
        }
        let originalRoot = (originalValue as? Self).flatMap { selected.matches($0) ? $0 : nil }
        return selected.associatedValues.enumerated().map { offset, field in
            let childContext = SBJEditTraversalContext(
                treeLevel: context.treeLevel + 1,
                itemIdentifier: context.itemIdentifier
                    .appending("case:\(selected.name)")
                    .appending("property:\(field.name)"),
                indexPath: context.indexPath.appending("field:\(offset)"),
                navigationPath: context.navigationPath + [field.name],
                branch: context.branch.child
            )
            return field.boundTraversalNode(root: root, originalRoot: originalRoot, registry: registry, context: childContext)
        }
    }

    @MainActor
    internal static func _sbjMakeAssociatedEnumEditor(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue? = nil,
        registry: SBJEditorRegistry,
        focusRequest: SBJEditorFocusRequest? = nil,
        labelIsUnknown: Bool = false,
        context: SBJEditTraversalContext = .root,
        headerOnly: Bool = false
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
                context: context,
                rowStatus: context.branch.status
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
