#if !os(tvOS) && !os(watchOS)
import SwiftUI

enum SBJEditorRootValidationResult {
    case uncomputed
    case computed(SBJValidationError?)

    func resolving<Root>(_ root: Root) -> SBJValidationError? {
        switch self {
        case .uncomputed:
            return SBJInvariantCheck.validationError(
                root,
                at: SBJValidationKeyPath(\Root.self)
            )
        case .computed(let error):
            return error
        }
    }
}



/// Type-erased metadata for one writable property on `Root`.
///
/// Editor fields are UI metadata: they hold SwiftUI bindings and view factories,
/// so the entire abstraction is isolated to the main actor. Keeping construction
/// and use in the same isolation domain also prevents writable key paths from
/// being transferred into a main-actor closure from a nonisolated context.
@MainActor
public struct SBJEditorField<Root: SBJSwiftUIEditable> {
    public let name: String
    public let editableField: SBJEditableField<Root>
    private let makeView: (Binding<Root>, Root?, SBJEditorRegistry, String?, SBJEditorFocusRequest?, Bool, SBJEditTraversalContext) -> AnyView
    private let collectIssues: (Root, [String], SBJEditorRegistry) -> [SBJEditorCapabilityIssue]

    public init<Value: Codable>(
        name: String,
        _ keyPath: WritableKeyPath<Root, Value>
    ) {
        self.name = name
        let editableField = SBJEditableField<Root>(name: name, keyPath)
        self.editableField = editableField
        let metadata = editableField.structuralMetadata
        let propertyInfo = metadata?.info
        let presentation = metadata?.hints.compactMap { hint -> SBJPropertyPresentation? in
            if case let .presentation(value) = hint { return value }
            return nil
        }.first
        let textStyle = metadata?.hints.compactMap { hint -> SBJStringStyle? in
            if case let .textStyle(style) = hint { return style }
            return nil
        }.first
        let textAutocorrection = metadata?.hints.compactMap { hint -> SBJTextAutocorrection? in
            if case let .textAutocorrection(value) = hint { return value }
            return nil
        }.first ?? .automatic
        let textCapitalization = metadata?.hints.compactMap { hint -> SBJTextCapitalization? in
            if case let .textCapitalization(value) = hint { return value }
            return nil
        }.first ?? .automatic
        let textMaximumLength = metadata?.constraints.compactMap { constraint -> Int? in
            if case let .textLength(_, maximum) = constraint { return maximum }
            return nil
        }.first
        let integerRange = metadata?.constraints.compactMap { constraint -> ClosedRange<Int>? in
            switch constraint {
            case let .integerRange(range): return range
            case let .integerMinimum(minimum): return minimum...Int.max
            default: return nil
            }
        }.first
        let numberRange = metadata?.constraints.compactMap { constraint -> ClosedRange<Double>? in
            switch constraint {
            case let .numberRange(range): return range
            case let .numberMinimum(minimum): return minimum...Double.greatestFiniteMagnitude
            default: return nil
            }
        }.first
        let dateRange = metadata?.constraints.compactMap { constraint -> ClosedRange<Date>? in
            if case let .dateRange(range) = constraint { return range }
            return nil
        }.first
        let colorSupportsAlpha = metadata?.hints.compactMap { hint -> Bool? in
            if case let .colorSupportsAlpha(value) = hint { return value }
            return nil
        }.first ?? true
        let collectionReorderable = metadata?.hints.compactMap { hint -> Bool? in
            if case let .reorderable(value) = hint { return value }
            return nil
        }.first ?? true
        let collectionItemTitleKey = metadata?.hints.compactMap { hint -> String? in
            if case let .itemTitle(value) = hint { return value }
            return nil
        }.first
        let collectionItemIdentifierKey = metadata?.constraints.compactMap { constraint -> String? in
            if case let .uniqueBy(value) = constraint {
                return value.split(separator: ".").last.map(String.init)
            }
            return nil
        }.first
        self.makeView = { root, originalRoot, registry, overrideName, focusRequest, labelIsUnknown, context in
            let defaultValue = Binding<Value>(
                get: { root.wrappedValue[keyPath: keyPath] },
                set: { root.wrappedValue[keyPath: keyPath] = $0 }
            )
            let value = registry.customBinding(keyPath: keyPath, root: root) ?? defaultValue
            let originalValue = originalRoot.map { $0[keyPath: keyPath] }
            let label = overrideName ?? name
            let defaultContent = SBJValueEditor.makeView(
                    label: label,
                    value: value,
                    originalValue: originalValue.map { SBJEditorOriginalValue($0) },
                    registry: registry,
                    presentation: presentation,
                    textStyle: textStyle,
                    textMaximumLength: textMaximumLength,
                    integerRange: integerRange,
                    numberRange: numberRange,
                    dateRange: dateRange,
                    colorSupportsAlpha: colorSupportsAlpha,
                    collectionReorderable: collectionReorderable,
                    collectionItemTitleKey: collectionItemTitleKey,
                    collectionItemIdentifierKey: collectionItemIdentifierKey,
                    focusRequest: focusRequest,
                    labelIsUnknown: labelIsUnknown,
                    context: context
                )
            let content = registry.customLineItem(
                keyPath: keyPath,
                label: label,
                binding: value,
                defaultContent: defaultContent
            ) ?? defaultContent
            let visuallyIneffective = Root.sbjEditorFieldIsVisuallyIneffective(
                keyPath,
                in: root.wrappedValue
            )
            return AnyView(
                SBJEditorPropertyInfoContainer(content: content, propertyName: name, info: propertyInfo)
                    .sbjTextInputPolicies(
                        autocorrection: textAutocorrection,
                        capitalization: textCapitalization
                    )
                    .environment(\.sbjEditorVisuallyIneffective, visuallyIneffective)
                    .sbjEditorNavigationAnchor(for: context.navigationPath)
            )
        }
        self.collectIssues = { root, path, registry in
            SBJValueEditor.collectIssues(
                value: root[keyPath: keyPath],
                path: path + [name],
                registry: registry,
                collectionItemTitleKey: collectionItemTitleKey
            )
        }
    }

    /// Creates an editor field that is intentionally outside `Root`'s structural
    /// metadata. `Value` does not need to be `Codable`; the application may
    /// provide an exact-type editor through `SBJEditorRegistry`.
    public init<Value>(
        editorOnlyName name: String,
        _ keyPath: WritableKeyPath<Root, Value>
    ) {
        self.name = name
        self.editableField = SBJEditableField<Root>(editorOnlyName: name, keyPath)
        self.makeView = { root, originalRoot, registry, overrideName, focusRequest, labelIsUnknown, context in
            let defaultValue = Binding<Value>(
                get: { root.wrappedValue[keyPath: keyPath] },
                set: { root.wrappedValue[keyPath: keyPath] = $0 }
            )
            let value = registry.customBinding(keyPath: keyPath, root: root) ?? defaultValue
            let label = overrideName ?? name
            let defaultContent = SBJValueEditor.makeView(
                label: label,
                value: value,
                originalValue: originalRoot.map { SBJEditorOriginalValue($0[keyPath: keyPath]) },
                registry: registry,
                focusRequest: focusRequest,
                labelIsUnknown: labelIsUnknown,
                context: context
            )
            let content = registry.customLineItem(
                keyPath: keyPath,
                label: label,
                binding: value,
                defaultContent: defaultContent
            ) ?? defaultContent
            return AnyView(
                SBJEditorPropertyInfoContainer(content: content, propertyName: name, info: nil)
                    .sbjEditorNavigationAnchor(for: context.navigationPath)
            )
        }
        self.collectIssues = { _, _, _ in [] }
    }

    func containsEmptyContent(
        root: Root,
        registry: SBJEditorRegistry
    ) -> Bool {
        editableField.containsEmptyContent(
            in: root,
            treatingAsLeaf: { registry.hasCustomEditor($0) }
        )
    }

    func issues(
        root: Root,
        path: [String],
        registry: SBJEditorRegistry
    ) -> [SBJEditorCapabilityIssue] {
        collectIssues(root, path, registry)
    }

    func isIncluded(
        root: Root,
        originalRoot: Root? = nil,
        registry: SBJEditorRegistry,
        criteria: SBJEditSearchCriteria
    ) -> Bool {
        criteria.includes(
            isChanged: editableField.hasChanged(in: root, from: originalRoot),
            containsEmptyContent: containsEmptyContent(root: root, registry: registry),
            matchesSearch: { query in
                editableField.matchesSearch(in: root, query: query)
            }
        )
    }

    func view(
        root: Binding<Root>,
        originalRoot: Root? = nil,
        registry: SBJEditorRegistry,
        nameOverride: String? = nil,
        focusRequest: SBJEditorFocusRequest? = nil,
        labelIsUnknown: Bool = false,
        context: SBJEditTraversalContext = .root,
        rootValidation: SBJEditorRootValidationResult = .uncomputed,
        applyFiltering: Bool = true
    ) -> AnyView {
        let changed = editableField.hasChanged(in: root.wrappedValue, from: originalRoot)
        let contentState = editableField.hasContent(in: root.wrappedValue)
        let rootValidationError = rootValidation.resolving(root.wrappedValue)
        let invalid = editableField.participatesInStructuralValidation && (
            editableField.validationError(in: root.wrappedValue) != nil ||
            (rootValidationError?.keyPath.contains(property: editableField.keyPath) == true)
        )
        let rendered = AnyView(
            makeView(root, originalRoot, registry, nameOverride, focusRequest, labelIsUnknown, context)
                .environment(\.sbjEditorIsChanged, changed)
                .environment(\.sbjEditorHasContent, contentState)
                .environment(\.sbjEditorIsInvalid, invalid)
                .accessibilityIdentifier(context.itemIdentifier.description)
        )

        if !applyFiltering {
            return AnyView(rendered.id(context.itemIdentifier))
        }

        return AnyView(
            SBJEditorFilteredView(
                content: { rendered },
                isChanged: changed,
                matchesSearch: { query in
                    editableField.matchesSearch(in: root.wrappedValue, query: query)
                },
                containsEmptyContent: {
                    containsEmptyContent(root: root.wrappedValue, registry: registry)
                },
                navigationPath: context.navigationPath
            )
            .id(context.itemIdentifier)
        )
    }
}

@MainActor
struct SBJEditorFilteredView: View {
    let content: () -> AnyView
    let isChanged: Bool
    let matchesSearch: (String) -> Bool
    let containsEmptyContent: () -> Bool
    let navigationPath: [String]
    @Environment(\.sbjEditorSearchCriteria) private var searchCriteria
    @Environment(\.sbjEditorNavigationTarget) private var navigationTarget

    @ViewBuilder
    var body: some View {
        if navigationTarget?.contains(navigationPath) == true || searchCriteria.includes(
            isChanged: isChanged,
            containsEmptyContent: containsEmptyContent(),
            matchesSearch: matchesSearch
        ) {
            content()
        }
    }
}
#endif
