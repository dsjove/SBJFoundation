#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

private protocol _SBJOptionalValue {
    @MainActor
    static func _sbjOptionalEditor(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue?,
        registry: SBJEditorRegistry,
        textStyle: SBJStringStyle?,
        integerRange: ClosedRange<Int>?,
        numberRange: ClosedRange<Double>?,
        dateRange: ClosedRange<Date>?,
        colorSupportsAlpha: Bool,
        collectionReorderable: Bool,
        collectionItemTitleKey: String?,
        collectionItemIdentifierKey: String?,
        itemActions: SBJEditorItemActions?,
        focusRequest: SBJEditorFocusRequest?,
        context: SBJEditTraversalContext
    ) -> AnyView
}

private protocol _SBJCollectionValue {
    @MainActor
    static func _sbjCollectionEditor(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue?,
        registry: SBJEditorRegistry,
        textStyle: SBJStringStyle?,
        integerRange: ClosedRange<Int>?,
        numberRange: ClosedRange<Double>?,
        reorderable: Bool,
        itemTitleKey: String?,
        itemIdentifierKey: String?,
        itemActions: SBJEditorItemActions?,
        focusRequest: SBJEditorFocusRequest?,
        context: SBJEditTraversalContext
    ) -> AnyView
}

private protocol _SBJOptionalIssueValue {
    @MainActor
    static func _sbjCollectEditorIssues(
        value: Any,
        path: [String],
        registry: SBJEditorRegistry,
        collectionItemTitleKey: String?
    ) -> [SBJEditorCapabilityIssue]
}

private protocol _SBJCollectionIssueValue {
    @MainActor
    static func _sbjCollectEditorIssues(
        value: Any,
        path: [String],
        registry: SBJEditorRegistry,
        itemTitleKey: String?
    ) -> [SBJEditorCapabilityIssue]
}

extension Optional: _SBJOptionalIssueValue {
    @MainActor
    static func _sbjCollectEditorIssues(
        value: Any,
        path: [String],
        registry: SBJEditorRegistry,
        collectionItemTitleKey: String?
    ) -> [SBJEditorCapabilityIssue] {
        guard let optional = value as? Wrapped?, let wrapped = optional else { return [] }
        return SBJValueEditor.collectIssues(
            value: wrapped,
            path: path,
            registry: registry,
            collectionItemTitleKey: collectionItemTitleKey
        )
    }
}

extension Array: _SBJCollectionIssueValue {
    @MainActor
    static func _sbjCollectEditorIssues(
        value: Any,
        path: [String],
        registry: SBJEditorRegistry,
        itemTitleKey: String?
    ) -> [SBJEditorCapabilityIssue] {
        guard let values = value as? [Element] else { return [] }
        return values.enumerated().flatMap { offset, element in
            let title = SBJCollectionItemIdentification.arrayTitle(
                for: element,
                index: offset,
                itemTitleKey: itemTitleKey
            )
            return SBJValueEditor.collectIssues(
                value: element,
                path: path + [title],
                registry: registry
            )
        }
    }
}


extension Set: _SBJCollectionIssueValue {
    @MainActor
    static func _sbjCollectEditorIssues(
        value: Any,
        path: [String],
        registry: SBJEditorRegistry,
        itemTitleKey: String?
    ) -> [SBJEditorCapabilityIssue] {
        guard let values = value as? Set<Element> else { return [] }
        return SBJCollectionOrdering.sorted(values).flatMap { element in
            let title = SBJCollectionItemIdentification.title(for: element, itemTitleKey: itemTitleKey)
            return SBJValueEditor.collectIssues(
                value: element,
                path: path + [title],
                registry: registry
            )
        }
    }
}

extension Dictionary: _SBJCollectionIssueValue {
    @MainActor
    static func _sbjCollectEditorIssues(
        value: Any,
        path: [String],
        registry: SBJEditorRegistry,
        itemTitleKey: String?
    ) -> [SBJEditorCapabilityIssue] {
        guard let values = value as? [Key: Value] else { return [] }
        return SBJCollectionOrdering.sortedEntries(values).flatMap { key, element in
            SBJValueEditor.collectIssues(
                value: element,
                path: path + ["[\(String(describing: key))]"],
                registry: registry
            )
        }
    }
}

extension Optional: _SBJOptionalValue where Wrapped: Codable {
    @MainActor
    static func _sbjOptionalEditor(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue?,
        registry: SBJEditorRegistry,
        textStyle: SBJStringStyle?,
        integerRange: ClosedRange<Int>?,
        numberRange: ClosedRange<Double>?,
        dateRange: ClosedRange<Date>?,
        colorSupportsAlpha: Bool,
        collectionReorderable: Bool,
        collectionItemTitleKey: String?,
        collectionItemIdentifierKey: String?,
        itemActions: SBJEditorItemActions?,
        focusRequest: SBJEditorFocusRequest?,
        context: SBJEditTraversalContext
    ) -> AnyView {
        let typed = binding.binding(as: Wrapped?.self)
        return AnyView(
            SBJOptionalEditor(
                label: label,
                value: typed,
                originalValue: originalValue.map { $0.value(as: Wrapped?.self) },
                registry: registry,
                textStyle: textStyle,
                integerRange: integerRange,
                numberRange: numberRange,
                dateRange: dateRange,
                colorSupportsAlpha: colorSupportsAlpha,
                collectionReorderable: collectionReorderable,
                collectionItemTitleKey: collectionItemTitleKey,
                collectionItemIdentifierKey: collectionItemIdentifierKey,
                itemActions: itemActions,
                focusRequest: focusRequest,
                context: context
            )
        )
    }
}

extension Array: _SBJCollectionValue where Element: Codable {
    @MainActor
    static func _sbjCollectionEditor(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue?,
        registry: SBJEditorRegistry,
        textStyle: SBJStringStyle?,
        integerRange: ClosedRange<Int>?,
        numberRange: ClosedRange<Double>?,
        reorderable: Bool,
        itemTitleKey: String?,
        itemIdentifierKey: String?,
        itemActions: SBJEditorItemActions?,
        focusRequest: SBJEditorFocusRequest?,
        context: SBJEditTraversalContext
    ) -> AnyView {
        let typed = binding.binding(as: [Element].self)
        return AnyView(
            SBJArrayEditor(
                label: label,
                value: typed,
                originalValue: originalValue.map { $0.value(as: [Element].self) },
                registry: registry,
                textStyle: textStyle,
                integerRange: integerRange,
                numberRange: numberRange,
                reorderable: reorderable,
                itemTitleKey: itemTitleKey,
                itemIdentifierKey: itemIdentifierKey,
                itemActions: itemActions,
                focusRequest: focusRequest,
                context: context
            )
        )
    }
}


extension Set: _SBJCollectionValue where Element: Codable {
    @MainActor
    static func _sbjCollectionEditor(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue?,
        registry: SBJEditorRegistry,
        textStyle: SBJStringStyle?,
        integerRange: ClosedRange<Int>?,
        numberRange: ClosedRange<Double>?,
        reorderable: Bool,
        itemTitleKey: String?,
        itemIdentifierKey: String?,
        itemActions: SBJEditorItemActions?,
        focusRequest: SBJEditorFocusRequest?,
        context: SBJEditTraversalContext
    ) -> AnyView {
        let typed = binding.binding(as: Set<Element>.self)
        return AnyView(
            SBJSetEditor(
                label: label,
                value: typed,
                originalValue: originalValue.map { $0.value(as: Set<Element>.self) },
                registry: registry,
                textStyle: textStyle,
                integerRange: integerRange,
                numberRange: numberRange,
                itemTitleKey: itemTitleKey,
                itemActions: itemActions,
                focusRequest: focusRequest,
                context: context
            )
        )
    }
}

extension Dictionary: _SBJCollectionValue where Key: Codable, Value: Codable {
    @MainActor
    static func _sbjCollectionEditor(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue?,
        registry: SBJEditorRegistry,
        textStyle: SBJStringStyle?,
        integerRange: ClosedRange<Int>?,
        numberRange: ClosedRange<Double>?,
        reorderable: Bool,
        itemTitleKey: String?,
        itemIdentifierKey: String?,
        itemActions: SBJEditorItemActions?,
        focusRequest: SBJEditorFocusRequest?,
        context: SBJEditTraversalContext
    ) -> AnyView {
        let typed = binding.binding(as: [Key: Value].self)
        return AnyView(
            SBJDictionaryEditor(
                label: label,
                value: typed,
                originalValue: originalValue.map { $0.value(as: [Key: Value].self) },
                registry: registry,
                textStyle: textStyle,
                integerRange: integerRange,
                numberRange: numberRange,
                itemActions: itemActions,
                focusRequest: focusRequest,
                context: context
            )
        )
    }
}

enum SBJValueEditor {
    @MainActor
    static func makeView<Value>(
        label: String,
        value: Binding<Value>,
        originalValue: SBJEditorOriginalValue? = nil,
        registry: SBJEditorRegistry,
        presentation: SBJPropertyPresentation? = nil,
        textStyle: SBJStringStyle? = nil,
        textMaximumLength: Int? = nil,
        integerRange: ClosedRange<Int>? = nil,
        numberRange: ClosedRange<Double>? = nil,
        dateRange: ClosedRange<Date>? = nil,
        colorSupportsAlpha: Bool = true,
        collectionReorderable: Bool = true,
        collectionItemTitleKey: String? = nil,
        collectionItemIdentifierKey: String? = nil,
        promotedTitlePropertyName: String? = nil,
        promotedTitlePrefix: String? = nil,
        itemActions: SBJEditorItemActions? = nil,
        focusRequest: SBJEditorFocusRequest? = nil,
        labelIsUnknown: Bool = false,
        context: SBJEditTraversalContext = .root
    ) -> AnyView {
        // Intentional built-in editor composition point. Concrete standard value
        // editors are selected here so the generic traversal/property layers do
        // not depend on them. Application-specific editors belong in the registry.
        if presentation == .fontFamily, Value.self == String?.self {
            return wrapLeaf(
                SBJFontFamilyEditor(
                    label: label,
                    value: value.sbjBinding(as: String?.self),
                    labelIsUnknown: labelIsUnknown
                ),
                itemActions: itemActions,
                treeLevel: context.treeLevel
            )
        }

        if let custom = registry.customEditor(label: label, binding: value) {
            return wrapLeaf(custom, itemActions: itemActions, treeLevel: context.treeLevel)
        }

        if Value.self == String.self {
            let binding = value.sbjBinding(as: String.self)
            switch textStyle ?? .singleLine {
            case .singleLine:
                return wrapLeaf(
                    SBJSingleLineTextEditor(label: label, value: binding, maximumLength: textMaximumLength, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown),
                    itemActions: itemActions,
                    treeLevel: context.treeLevel
                )
            case .multiline:
                return wrapLeaf(
                    SBJMultilineTextEditor(label: label, value: binding, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown),
                    itemActions: itemActions,
                    treeLevel: context.treeLevel
                )
            case .sheetEdit:
                return wrapLeaf(
                    SBJSheetTextEditor(label: label, value: binding, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown),
                    itemActions: itemActions,
                    treeLevel: context.treeLevel
                )
            }
        }
        if Value.self == Bool.self {
            let binding = value.sbjBinding(as: Bool.self)
            return wrapLeaf(SBJBooleanEditor(label: label, value: binding, labelIsUnknown: labelIsUnknown), itemActions: itemActions, treeLevel: context.treeLevel)
        }
        if Value.self == Int.self {
            return wrapLeaf(
                SBJIntegerEditor(label: label, value: value.sbjBinding(as: Int.self), range: integerRange, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown),
                itemActions: itemActions,
                treeLevel: context.treeLevel
            )
        }
        if Value.self == Double.self {
            return wrapLeaf(
                SBJDoubleEditor(label: label, value: value.sbjBinding(as: Double.self), range: numberRange, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown),
                itemActions: itemActions,
                treeLevel: context.treeLevel
            )
        }
        if Value.self == Float.self {
            let double = Binding<Double>(
                get: { Double(value.sbjBinding(as: Float.self).wrappedValue) },
                set: { value.sbjBinding(as: Float.self).wrappedValue = Float($0) }
            )
            return wrapLeaf(SBJDoubleEditor(label: label, value: double, range: numberRange, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown), itemActions: itemActions, treeLevel: context.treeLevel)
        }
        if Value.self == CGFloat.self {
            let double = Binding<Double>(
                get: { Double(value.sbjBinding(as: CGFloat.self).wrappedValue) },
                set: { value.sbjBinding(as: CGFloat.self).wrappedValue = CGFloat($0) }
            )
            return wrapLeaf(SBJDoubleEditor(label: label, value: double, range: numberRange, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown), itemActions: itemActions, treeLevel: context.treeLevel)
        }
        if Value.self == Decimal.self {
            return wrapLeaf(SBJDecimalEditor(label: label, value: value.sbjBinding(as: Decimal.self), range: numberRange, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown), itemActions: itemActions, treeLevel: context.treeLevel)
        }
        if Value.self == Int8.self { return numericTextView(label: label, value: value.sbjBinding(as: Int8.self), itemActions: itemActions, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown, treeLevel: context.treeLevel) }
        if Value.self == Int16.self { return numericTextView(label: label, value: value.sbjBinding(as: Int16.self), itemActions: itemActions, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown, treeLevel: context.treeLevel) }
        if Value.self == Int32.self { return numericTextView(label: label, value: value.sbjBinding(as: Int32.self), itemActions: itemActions, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown, treeLevel: context.treeLevel) }
        if Value.self == Int64.self { return numericTextView(label: label, value: value.sbjBinding(as: Int64.self), itemActions: itemActions, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown, treeLevel: context.treeLevel) }
        if Value.self == UInt.self { return numericTextView(label: label, value: value.sbjBinding(as: UInt.self), itemActions: itemActions, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown, treeLevel: context.treeLevel) }
        if Value.self == UInt8.self { return numericTextView(label: label, value: value.sbjBinding(as: UInt8.self), itemActions: itemActions, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown, treeLevel: context.treeLevel) }
        if Value.self == UInt16.self { return numericTextView(label: label, value: value.sbjBinding(as: UInt16.self), itemActions: itemActions, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown, treeLevel: context.treeLevel) }
        if Value.self == UInt32.self { return numericTextView(label: label, value: value.sbjBinding(as: UInt32.self), itemActions: itemActions, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown, treeLevel: context.treeLevel) }
        if Value.self == UInt64.self { return numericTextView(label: label, value: value.sbjBinding(as: UInt64.self), itemActions: itemActions, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown, treeLevel: context.treeLevel) }
        if Value.self == Date.self {
            return wrapLeaf(SBJDateEditor(label: label, value: value.sbjBinding(as: Date.self), range: dateRange, labelIsUnknown: labelIsUnknown), itemActions: itemActions, treeLevel: context.treeLevel)
        }
        if Value.self == URL.self {
            return wrapLeaf(SBJURLEditor(label: label, value: value.sbjBinding(as: URL.self), focusRequest: focusRequest, labelIsUnknown: labelIsUnknown), itemActions: itemActions, treeLevel: context.treeLevel)
        }
        if Value.self == UUID.self {
            return wrapLeaf(SBJUUIDEditor(label: label, value: value.sbjBinding(as: UUID.self), focusRequest: focusRequest, labelIsUnknown: labelIsUnknown), itemActions: itemActions, treeLevel: context.treeLevel)
        }
        if Value.self == Data.self {
            return wrapLeaf(SBJDataEditor(label: label, value: value.sbjBinding(as: Data.self), focusRequest: focusRequest, labelIsUnknown: labelIsUnknown), itemActions: itemActions, treeLevel: context.treeLevel)
        }
        if Value.self == CodableColor.self {
            return wrapLeaf(SBJColorEditor(label: label, value: value.sbjBinding(as: CodableColor.self), supportsAlpha: colorSupportsAlpha, labelIsUnknown: labelIsUnknown), itemActions: itemActions, treeLevel: context.treeLevel)
        }
        let erased = SBJAnyBinding(value)

        if let unitValue = Value.self as? any _SBJUnitValueEditorValue.Type {
            return wrapLeaf(
                unitValue._sbjMakeUnitValueEditor(
                    label: label,
                    binding: erased,
                    labelIsUnknown: labelIsUnknown
                ),
                itemActions: itemActions,
                treeLevel: context.treeLevel
            )
        }

        if let optional = Value.self as? any _SBJOptionalValue.Type {
            return optional._sbjOptionalEditor(
                label: label,
                binding: erased,
                originalValue: originalValue,
                registry: registry,
                textStyle: textStyle,
                integerRange: integerRange,
                numberRange: numberRange,
                dateRange: dateRange,
                colorSupportsAlpha: colorSupportsAlpha,
                collectionReorderable: collectionReorderable,
                collectionItemTitleKey: collectionItemTitleKey,
                collectionItemIdentifierKey: collectionItemIdentifierKey,
                itemActions: itemActions,
                focusRequest: focusRequest,
                context: context
            )
        }
        if let collection = Value.self as? any _SBJCollectionValue.Type {
            return collection._sbjCollectionEditor(
                label: label,
                binding: erased,
                originalValue: originalValue,
                registry: registry,
                textStyle: textStyle,
                integerRange: integerRange,
                numberRange: numberRange,
                reorderable: collectionReorderable,
                itemTitleKey: collectionItemTitleKey,
                itemIdentifierKey: collectionItemIdentifierKey,
                itemActions: itemActions,
                focusRequest: focusRequest,
                context: context
            )
        }
        if let associatedEnum = Value.self as? any SBJEditableAssociatedEnum.Type {
            return wrapLeaf(
                associatedEnum._sbjMakeAssociatedEnumEditor(
                    label: label,
                    binding: erased,
                    originalValue: originalValue,
                    registry: registry,
                    focusRequest: focusRequest,
                    labelIsUnknown: labelIsUnknown,
                    context: context
                ),
                itemActions: itemActions,
                treeLevel: context.treeLevel
            )
        }
        if let editable = Value.self as? any SBJSwiftUIEditable.Type {
            return editable._sbjMakeEditor(
                label: label,
                binding: erased,
                originalValue: originalValue,
                registry: registry,
                itemActions: itemActions,
                focusRequest: focusRequest,
                titleIsUnknown: labelIsUnknown,
                promotedTitlePropertyName: promotedTitlePropertyName,
                promotedTitlePrefix: promotedTitlePrefix,
                context: context
            )
        }
        if let options = caseIterableOptions(for: Value.self) {
            return wrapLeaf(
                SBJCaseIterableEditor(label: label, value: value, options: options, labelIsUnknown: labelIsUnknown),
                itemActions: itemActions,
                treeLevel: context.treeLevel
            )
        }

        // Unknown Codable values remain visible as unsupported rather than being
        // silently omitted. Applications can register a custom exact-type editor.
        return wrapLeaf(
            SBJUnsupportedEditor(label: label, type: Value.self, value: value.wrappedValue, labelIsUnknown: labelIsUnknown),
            itemActions: itemActions,
            treeLevel: context.treeLevel
        )
    }

    @MainActor
    static func collectIssues<Value>(
        value: Value,
        path: [String],
        registry: SBJEditorRegistry,
        collectionItemTitleKey: String? = nil
    ) -> [SBJEditorCapabilityIssue] {
        if registry.hasCustomEditor(Value.self) { return [] }
        if Value.self is any SBJTypedEditorValue.Type { return [] }

        if let optional = Value.self as? any _SBJOptionalIssueValue.Type {
            return optional._sbjCollectEditorIssues(
                value: value,
                path: path,
                registry: registry,
                collectionItemTitleKey: collectionItemTitleKey
            )
        }
        if let collection = Value.self as? any _SBJCollectionIssueValue.Type {
            return collection._sbjCollectEditorIssues(
                value: value,
                path: path,
                registry: registry,
                itemTitleKey: collectionItemTitleKey
            )
        }
        if let associatedEnum = Value.self as? any SBJEditableAssociatedEnum.Type {
            return associatedEnum._sbjCollectAssociatedEnumIssues(value: value, path: path, registry: registry)
        }
        if let editable = Value.self as? any SBJSwiftUIEditable.Type {
            return editable._sbjCollectIssues(value: value, path: path, registry: registry)
        }
        if caseIterableOptions(for: Value.self) != nil { return [] }

        return [
            SBJEditorCapabilityIssue(
                path: path.joined(separator: " • "),
                typeName: String(describing: Value.self),
                valueDescription: SBJValueDescription.describe(value)
            )
        ]
    }

    @MainActor
    private static func numericTextView<T: LosslessStringConvertible & FixedWidthInteger>(
        label: String,
        value: Binding<T>,
        itemActions: SBJEditorItemActions?,
        focusRequest: SBJEditorFocusRequest?,
        labelIsUnknown: Bool,
        treeLevel: Int
    ) -> AnyView {
        wrapLeaf(
            SBJLosslessNumericEditor(label: label, value: value, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown),
            itemActions: itemActions,
            treeLevel: treeLevel
        )
    }

    @MainActor
    private static func wrapLeaf<Content: View>(_ view: Content, itemActions: SBJEditorItemActions?, treeLevel: Int) -> AnyView {
        AnyView(
            SBJEditorRow(
                treeLevel: treeLevel,
                elementAction: itemActions?.leadingView,
                trailingActions: itemActions?.trailingView
            ) {
                view
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        )
    }


}
#endif
