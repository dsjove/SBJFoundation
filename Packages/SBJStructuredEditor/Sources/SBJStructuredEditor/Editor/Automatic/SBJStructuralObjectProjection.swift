import SBJDataDefinition
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// The automatic editor's projection of an ordinary structural model.
/// The schema and typed property dispatch remain owned by DataDefinition.
/// This is the sole projection for mutable structural object models.
@MainActor
extension SBJMutableStructure {
    private static var structuralFields: [SBJEditorPropertyDescriptor<Self>] {
        SBJStructuralFieldProjection.fields(of: Self.self)
    }

    static var _sbjStructuralFieldCount: Int { structuralFields.count }

    static func _sbjStructuralTraversalNodes(
        value: Any, context: SBJEditTraversalContext
    ) -> [SBJEditorTraversalNode] {
        guard let root = value as? Self else { return [] }
        let fields = structuralFields
        let locations = SBJEditorStructuralLocations.resolve(fields, of: Self.self)
        return fields.enumerated().map { offset, field in
            let childContext = structuralContext(for: field, location: locations[offset], parent: context, bound: false)
            return field.traversalNode(root: root, context: childContext)
        }
    }

    static func _sbjStructuralBoundNodes(
        binding: SBJAnyBinding, originalValue: Any?, registry: SBJEditorRegistry,
        context: SBJEditTraversalContext
    ) -> [SBJEditorTraversalNode] {
        let root: Binding<Self> = binding.binding(as: Self.self)
        let original = originalValue as? Self
        let fields = structuralFields
        let locations = SBJEditorStructuralLocations.resolve(fields, of: Self.self)
        return fields.enumerated().map { offset, field in
            let childContext = structuralContext(for: field, location: locations[offset], parent: context, bound: true)
            return field.boundTraversalNode(root: root, originalRoot: original, registry: registry, context: childContext)
        }
    }

    private static func structuralContext(
        for field: SBJEditorPropertyDescriptor<Self>,
        location: (identity: String, location: String),
        parent: SBJEditTraversalContext, bound: Bool
    ) -> SBJEditTraversalContext {
        return SBJEditTraversalContext(
            treeLevel: bound && parent.itemIdentifier == .root ? parent.treeLevel : parent.treeLevel + 1,
            itemIdentifier: parent.itemIdentifier.appending(location.identity),
            indexPath: parent.indexPath.appending(location.location),
            navigationPath: parent.navigationPath + [field.name],
            branch: parent.branch.child
        )
    }

    static func _sbjStructuralCollectIssues(
        value: Any, path: [String], registry: SBJEditorRegistry
    ) -> [SBJEditorCapabilityIssue] {
        guard let value = value as? Self else { return [] }
        return structuralFields.flatMap { $0.issues(root: value, path: path, registry: registry) }
    }

    static func _sbjStructuralMakeEditor(
        label: String, binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue?, registry: SBJEditorRegistry,
        itemActions: SBJEditorItemActions?, focusRequest: SBJEditorFocusRequest?,
        titleIsUnknown: Bool, promotedTitlePropertyName: String?,
        promotedTitlePrefix: String?, context: SBJEditTraversalContext,
        headerOnly: Bool
    ) -> AnyView {
        AnyView(SBJObjectEditor(
            fields: structuralFields,
            title: label, value: binding.binding(as: Self.self),
            originalValue: originalValue.map { $0.value(as: Self.self) },
            registry: registry, itemActions: itemActions, focusRequest: focusRequest,
            titleIsUnknown: titleIsUnknown,
            promotedTitlePropertyName: promotedTitlePropertyName,
            promotedTitlePrefix: promotedTitlePrefix, context: context,
            headerOnly: headerOnly
        ))
    }
}
#endif
