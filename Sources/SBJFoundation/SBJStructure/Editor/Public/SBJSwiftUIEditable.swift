#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// SwiftUI rendering capability layered on top of the UI-independent
/// ``SBJMutableStructure`` model description.
///
/// `@SBJStructure` synthesizes this conformance together with `SBJMutableStructure`.
public protocol SBJSwiftUIEditable: SBJMutableStructure {
    @MainActor
    static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] { get }

    /// Returns whether an editor field should be presented with an inactive
    /// appearance while remaining fully interactive.
    ///
    /// This is presentation state only: implementations must not use it to
    /// change or normalize the stored value.
    @MainActor
    static func sbjEditorFieldIsVisuallyIneffective<Value>(
        _ keyPath: WritableKeyPath<Self, Value>,
        in root: Self
    ) -> Bool
}

public extension SBJSwiftUIEditable {
    @MainActor
    static func sbjEditorFieldIsVisuallyIneffective<Value>(
        _ keyPath: WritableKeyPath<Self, Value>,
        in root: Self
    ) -> Bool {
        false
    }

    /// Enumerates immediate structured child fields as logical nodes without
    /// instantiating editor controls. Descendants are produced on demand.
    @MainActor
    internal static func _sbjTraversalNodes(
        value: Any,
        context: SBJEditTraversalContext
    ) -> [SBJEditorTraversalNode] {
        guard let root = value as? Self else { return [] }
        return Self.sbjEditorFields.enumerated().map { offset, field in
            let childContext = SBJEditTraversalContext(
                treeLevel: context.treeLevel + 1,
                itemIdentifier: context.itemIdentifier.appending("property:\(field.name)"),
                indexPath: context.indexPath.appending("field:\(offset)"),
                navigationPath: context.navigationPath + [field.name],
                branch: context.branch.child
            )
            return field.traversalNode(root: root, context: childContext)
        }
    }

    /// Binding-backed top-level fields suitable for independent lazy rows.
    /// Compound descendants still require dedicated binding adapters.
    @MainActor
    internal static func _sbjBoundRootNodes(
        binding: Binding<Self>,
        originalValue: Self? = nil,
        registry: SBJEditorRegistry,
        context: SBJEditTraversalContext = .root
    ) -> [SBJEditorTraversalNode] {
        Self.sbjEditorFields.enumerated().map { offset, field in
            let childContext = SBJEditTraversalContext(
                treeLevel: context.itemIdentifier == .root ? context.treeLevel : context.treeLevel + 1,
                itemIdentifier: context.itemIdentifier.appending("property:\(field.name)"),
                indexPath: context.indexPath.appending("field:\(offset)"),
                navigationPath: context.navigationPath + [field.name],
                branch: context.branch.child
            )
            return field.boundTraversalNode(
                root: binding,
                originalRoot: originalValue,
                registry: registry,
                context: childContext
            )
        }
    }

    /// Bridges a type-erased live binding into the structured value's typed
    /// field descriptors. The descendants retain bindings, not model snapshots.
    @MainActor
    internal static func _sbjBoundTraversalNodes(
        binding: SBJAnyBinding,
        originalValue: Any? = nil,
        registry: SBJEditorRegistry,
        context: SBJEditTraversalContext
    ) -> [SBJEditorTraversalNode] {
        _sbjBoundRootNodes(
            binding: binding.binding(as: Self.self),
            originalValue: originalValue as? Self,
            registry: registry,
            context: context
        )
    }

    /// Type-erased field count used by the recursive SwiftUI editor.
    @MainActor
    internal static var _sbjEditorFieldCount: Int {
        Self.sbjEditorFields.count
    }

    @MainActor
    internal static func _sbjCollectIssues(
        value: Any,
        path: [String],
        registry: SBJEditorRegistry
    ) -> [SBJEditorCapabilityIssue] {
        guard let typed = value as? Self else { return [] }
        return Self.sbjEditorFields.flatMap { field in
            field.issues(root: typed, path: path, registry: registry)
        }
    }

    @MainActor
    internal static func _sbjMakeEditor(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue? = nil,
        registry: SBJEditorRegistry,
        itemActions: SBJEditorItemActions? = nil,
        focusRequest: SBJEditorFocusRequest? = nil,
        titleIsUnknown: Bool = false,
        promotedTitlePropertyName: String? = nil,
        promotedTitlePrefix: String? = nil,
        context: SBJEditTraversalContext = .root,
        headerOnly: Bool = false
    ) -> AnyView {
        let typedBinding = binding.binding(as: Self.self)

        return AnyView(
            SBJObjectEditor(
                title: label,
                value: typedBinding,
                originalValue: originalValue.map { $0.value(as: Self.self) },
                registry: registry,
                itemActions: itemActions,
                focusRequest: focusRequest,
                titleIsUnknown: titleIsUnknown,
                promotedTitlePropertyName: promotedTitlePropertyName,
                promotedTitlePrefix: promotedTitlePrefix,
                context: context,
                headerOnly: headerOnly
            )
        )
    }

    /// A header-only object factory for independently projected descendants.
    /// Unlike `_sbjMakeEditor`, this never constructs child field views.
    @MainActor
    internal static func _sbjMakeEditorHeader(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue? = nil,
        registry: SBJEditorRegistry,
        itemActions: SBJEditorItemActions? = nil,
        focusRequest: SBJEditorFocusRequest? = nil,
        titleIsUnknown: Bool = false,
        promotedTitlePropertyName: String? = nil,
        promotedTitlePrefix: String? = nil,
        context: SBJEditTraversalContext = .root
    ) -> AnyView {
        AnyView(
            SBJObjectEditor(
                title: label,
                value: binding.binding(as: Self.self),
                originalValue: originalValue.map { $0.value(as: Self.self) },
                registry: registry,
                itemActions: itemActions,
                focusRequest: focusRequest,
                titleIsUnknown: titleIsUnknown,
                promotedTitlePropertyName: promotedTitlePropertyName,
                promotedTitlePrefix: promotedTitlePrefix,
                context: context,
                headerOnly: true
            )
        )
    }

}
#endif
