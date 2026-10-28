import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
  import SwiftUI

  /// Configuration distilled from structural property metadata for one editor field.
  @MainActor
  struct SBJEditFieldConfiguration {
    let propertyInfo: SBJPropertyInfo?
    let stringPresentation: SBJStringPresentationValue
    let textMaximumLength: Int?
    let integerRange: ClosedRange<Int>?
    let numberRange: ClosedRange<Double>?
    let dateRange: ClosedRange<Date>?
    let colorSupportsAlpha: Bool
    let unitEditor: SBJUnitValueEditorMode
    let unitSystem: MeasurementSystem?
    let collectionInsertable: Bool
    let collectionRemovable: Bool
    let collectionReorderable: Bool
    let collectionElementPresentation: SBJFieldPresentationValue?
    let dictionaryPresentation: SBJDictionaryPresentationValue?
    let collectionItemTitleKey: String?
    let collectionItemIdentifierKey: String?

    init<Root: SBJStructured>(metadata: SBJPropertyMetadata<Root>?) {
      propertyInfo = metadata?.info
      let stringPresentation = metadata?.hints.compactMap { hint -> SBJStringPresentationValue? in
        if case .stringPresentation(let value) = hint { return value }
        return nil
      }.first
      self.stringPresentation = stringPresentation ?? .init()
      textMaximumLength =
        metadata?.constraints.compactMap { constraint -> Int? in
          if case .stringRules(let rules) = constraint { return rules.maxLength }
          return nil
        }.first
      integerRange =
        metadata?.constraints.compactMap { constraint -> ClosedRange<Int>? in
          switch constraint {
          case .integerRules(let rules):
            if let range = rules.range { return range }
            if let minimum = rules.min { return minimum...Int.max }
            return nil
          default: return nil
          }
        }.first
      numberRange =
        metadata?.constraints.compactMap { constraint -> ClosedRange<Double>? in
          switch constraint {
          case .numberRules(let rules):
            if let range = rules.range { return range }
            if let minimum = rules.min { return minimum...Double.greatestFiniteMagnitude }
            return nil
          default: return nil
          }
        }.first
      dateRange =
        metadata?.constraints.compactMap { constraint -> ClosedRange<Date>? in
          if case .dateRules(let rules) = constraint { return rules.range }
          return nil
        }.first
      colorSupportsAlpha =
        metadata?.hints.compactMap { hint -> Bool? in
          if case .colorPresentation(let value) = hint { return value.alpha }
          return nil
        }.first ?? true
      let unitPresentation = metadata?.hints.compactMap { hint -> SBJUnitValuePresentationValue? in
        if case .unitValuePresentation(let value) = hint { return value }
        return nil
      }.first
      let ruleUnitEditor = metadata?.constraints.compactMap { constraint -> SBJUnitValueEditorMode? in
        if case .unitMutable(let value) = constraint { return value ? .editable : .fixedUnit }
        return nil
      }.first
      if let unitPresentation {
        unitEditor = unitPresentation.mode == .editable ? .editable : .fixedUnit
      } else {
        unitEditor = ruleUnitEditor ?? .editable
      }
      unitSystem = metadata?.constraints.compactMap { constraint -> MeasurementSystem? in
        if case .unitSystem(let system) = constraint { return system }
        return nil
      }.first
      let arrayPresentation = metadata?.hints.compactMap { hint -> SBJArrayPresentationValue? in
        if case .arrayPresentation(let value) = hint { return value }
        return nil
      }.first
      let setPresentation = metadata?.hints.compactMap { hint -> SBJSetPresentationValue? in
        if case .setPresentation(let value) = hint { return value }
        return nil
      }.first
      let dictionaryControls = metadata?.hints.compactMap { hint -> SBJDictionaryPresentationValue? in
        if case .dictionaryPresentation(let value) = hint { return value }
        return nil
      }.first
      collectionInsertable = arrayPresentation?.insertable ?? setPresentation?.insertable ?? dictionaryControls?.insertable ?? true
      collectionRemovable = arrayPresentation?.removable ?? setPresentation?.removable ?? dictionaryControls?.removable ?? true
      collectionReorderable = arrayPresentation?.reorderable ?? true
      dictionaryPresentation = metadata?.hints.compactMap { hint -> SBJDictionaryPresentationValue? in
        if case .dictionaryPresentation(let value) = hint { return value }
        return nil
      }.first
      collectionElementPresentation = metadata?.hints.compactMap { hint -> SBJFieldPresentationValue? in
        if case .elementFieldPresentation(let value) = hint { return value }
        return nil
      }.first
      collectionItemTitleKey =
        metadata?.hints.compactMap { hint -> String? in
          if case .itemTitle(let value) = hint { return value }
          return nil
        }.first
      collectionItemIdentifierKey =
        metadata?.constraints.compactMap { constraint -> String? in
          if case .uniqueBy(let value) = constraint {
            return value.split(separator: ".").last.map(String.init)
          }
          return nil
        }.first
    }
  }

  /// A reusable SBJFoundation editor for one bound value.
  ///
  /// Use the binding initializer when the value is not part of an `@SBJStructure`
  /// model, or when a hand-built form wants to provide presentation hints directly:
  ///
  /// ```swift
  /// SBJEditField("Name", value: $name)
  /// ```
  ///
  /// Use the root/key-path initializer for a property on an `SBJMutableStructure`
  /// model. That form reuses the property's generated metadata and key-path-specific
  /// registry customizations, matching the field rendered by the automatic editor:
  ///
  /// ```swift
  /// SBJEditField(root: $recipe, keyPath: \.servings)
  /// ```
  @MainActor
  public struct SBJEditField<Value>: View {
    private let render: () -> AnyView

    /// Creates a standalone editor for an arbitrary binding.
    ///
    /// This form selects the same stock value editor as the automatic editor, but
    /// it has no model/key-path context. Supply presentation options directly when
    /// a hand-built form needs them.
    public init(
      _ label: String,
      value: Binding<Value>,
      registry: SBJEditorRegistry = .init(),
      textStyle: SBJStringStyle? = nil,
      textMaximumLength: Int? = nil,
      integerRange: ClosedRange<Int>? = nil,
      numberRange: ClosedRange<Double>? = nil,
      dateRange: ClosedRange<Date>? = nil,
      colorSupportsAlpha: Bool = true,
      unitEditor: SBJUnitValueEditorMode = .editable,
      unitSystem: MeasurementSystem? = nil,
      collectionReorderable: Bool = true
    ) {
      render = {
        SBJValueEditor.makeView(
          label: label,
          value: value,
          registry: registry,
          textStyle: textStyle,
          textMaximumLength: textMaximumLength,
          integerRange: integerRange,
          numberRange: numberRange,
          dateRange: dateRange,
          colorSupportsAlpha: colorSupportsAlpha,
          unitEditor: unitEditor,
          unitSystem: unitSystem,
          collectionReorderable: collectionReorderable
        )
      }
    }

    /// Creates a model-aware editor for one structured property.
    ///
    /// The label and presentation configuration are read from the property's
    /// generated structural metadata. Exact-key-path bindings and whole-line
    /// replacements registered in `registry` are honored as well.
    public init<Root: SBJMutableStructure>(
      root: Binding<Root>,
      keyPath: WritableKeyPath<Root, Value>,
      originalRoot: Root? = nil,
      registry: SBJEditorRegistry = .init()
    ) where Value: Codable {
      let metadata = Root.propertyMetadata(for: keyPath)
      let label =
        metadata?.displayName
        ?? Root.sbjMutableProperties.first(where: { ($0.keyPath as AnyKeyPath) == (keyPath as AnyKeyPath) })?.name
        ?? "Value"
      self.init(
        root: root,
        originalRoot: originalRoot,
        keyPath: keyPath,
        label: label,
        propertyName: metadata?.displayName ?? label,
        registry: registry,
        configuration: SBJEditFieldConfiguration(metadata: metadata),
        focusRequest: nil,
        labelIsUnknown: metadata == nil,
        context: .root
      )
    }

    init<Root: SBJMutableStructure>(
      root: Binding<Root>,
      originalRoot: Root?,
      keyPath: WritableKeyPath<Root, Value>,
      label: String,
      propertyName: String,
      registry: SBJEditorRegistry,
      configuration: SBJEditFieldConfiguration,
      focusRequest: SBJEditorFocusRequest?,
      labelIsUnknown: Bool,
      context: SBJEditTraversalContext,
      headerOnly: Bool = false
    ) {
      render = {
        let defaultValue = Binding<Value>(
          get: { root.wrappedValue[keyPath: keyPath] },
          set: { root.wrappedValue[keyPath: keyPath] = $0 }
        )
        let value = registry.customBinding(keyPath: keyPath, root: root) ?? defaultValue
        let defaultContent = SBJValueEditor.makeView(
          label: label,
          value: value,
          originalValue: originalRoot.map { SBJEditorOriginalValue($0[keyPath: keyPath]) },
          registry: registry,
          stringPresentation: configuration.stringPresentation,
          textMaximumLength: configuration.textMaximumLength,
          integerRange: configuration.integerRange,
          numberRange: configuration.numberRange,
          dateRange: configuration.dateRange,
          colorSupportsAlpha: configuration.colorSupportsAlpha,
          unitEditor: configuration.unitEditor,
          unitSystem: configuration.unitSystem,
          collectionInsertable: configuration.collectionInsertable,
          collectionRemovable: configuration.collectionRemovable,
          collectionReorderable: configuration.collectionReorderable,
          collectionItemTitleKey: configuration.collectionItemTitleKey,
          collectionItemIdentifierKey: configuration.collectionItemIdentifierKey,
          focusRequest: focusRequest,
          labelIsUnknown: labelIsUnknown,
          context: context,
          headerOnly: headerOnly
        )
        let content =
          registry.customLineItem(
            keyPath: keyPath,
            label: label,
            binding: value,
            defaultContent: defaultContent
          ) ?? defaultContent
        return AnyView(
          SBJEditorPropertyInfoContainer(
            content: AnyView(content),
            propertyName: propertyName,
            info: configuration.propertyInfo,
            caseInfo: { SBJEditorEnumCaseInformation.info(for: value.wrappedValue) },
            branch: context.branch
          )
          .sbjEditorNavigationAnchor(for: context.navigationPath)
        )
      }
    }

    init<Root: SBJMutableStructure>(
      editorOnlyRoot root: Binding<Root>,
      originalRoot: Root?,
      keyPath: WritableKeyPath<Root, Value>,
      label: String,
      registry: SBJEditorRegistry,
      focusRequest: SBJEditorFocusRequest?,
      labelIsUnknown: Bool,
      context: SBJEditTraversalContext,
      headerOnly: Bool = false
    ) {
      render = {
        let defaultValue = Binding<Value>(
          get: { root.wrappedValue[keyPath: keyPath] },
          set: { root.wrappedValue[keyPath: keyPath] = $0 }
        )
        let value = registry.customBinding(keyPath: keyPath, root: root) ?? defaultValue
        let defaultContent = SBJValueEditor.makeView(
          label: label,
          value: value,
          originalValue: originalRoot.map { SBJEditorOriginalValue($0[keyPath: keyPath]) },
          registry: registry,
          focusRequest: focusRequest,
          labelIsUnknown: labelIsUnknown,
          context: context,
          headerOnly: headerOnly
        )
        let content =
          registry.customLineItem(
            keyPath: keyPath,
            label: label,
            binding: value,
            defaultContent: defaultContent
          ) ?? defaultContent
        return AnyView(
          SBJEditorPropertyInfoContainer(content: content, propertyName: label, info: nil, branch: context.branch)
            .sbjEditorNavigationAnchor(for: context.navigationPath)
        )
      }
    }

    public var body: some View {
      render()
    }
  }
#endif
