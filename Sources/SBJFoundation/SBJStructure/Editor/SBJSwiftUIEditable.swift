#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// SwiftUI rendering capability layered on top of the UI-independent
/// ``SBJEditable`` model description.
///
/// `@SBJStructure` synthesizes this conformance together with `SBJEditable`.
public protocol SBJSwiftUIEditable: SBJEditable {
    @MainActor
    static var sbjEditorFields: [SBJEditorField<Self>] { get }

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
        context: SBJEditTraversalContext = .root
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
                context: context
            )
        )
    }

    @MainActor
    internal static func _sbjMakeEditorContents(
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue? = nil,
        registry: SBJEditorRegistry,
        focusRequest: SBJEditorFocusRequest? = nil,
        context: SBJEditTraversalContext = .root
    ) -> AnyView {
        let typedBinding = binding.binding(as: Self.self)
        let rootValidation = SBJEditorRootValidationResult.computed(
            SBJInvariantCheck.validationError(
                typedBinding.wrappedValue,
                at: SBJValidationKeyPath(\Self.self)
            )
        )
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Self.sbjEditorFields.enumerated().map { offset, field in
                    SBJEditorSnapshotItem(
                        itemIdentifier: context.itemIdentifier.appending("property:\(field.name)"),
                        indexPath: context.indexPath.appending("field:\(offset)"),
                        content: field
                    )
                }) { item in
                    let field = item.content
                    field.view(
                        root: typedBinding,
                        originalRoot: originalValue.map { $0.value(as: Self.self) },
                        registry: registry,
                        focusRequest: focusRequest,
                        context: SBJEditTraversalContext(
                            treeLevel: context.treeLevel + 1,
                            itemIdentifier: item.itemIdentifier,
                            indexPath: item.indexPath,
                            navigationPath: context.navigationPath + [field.name]
                        ),
                        rootValidation: rootValidation
                    )
                }
            }
        )
    }
}
#endif
