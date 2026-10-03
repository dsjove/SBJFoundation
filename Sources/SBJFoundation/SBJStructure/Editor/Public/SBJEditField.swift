#if !os(tvOS) && !os(watchOS)
  import SwiftUI

  /// Configuration distilled from structural property metadata for one editor field.
  @MainActor
  struct SBJEditFieldConfiguration {
    let propertyInfo: SBJPropertyInfo?
    let presentation: SBJPropertyPresentation?
    let textStyle: SBJStringStyle?
    let textAutocorrection: SBJTextAutocorrection
    let textCapitalization: SBJTextCapitalization
    let textMaximumLength: Int?
    let integerRange: ClosedRange<Int>?
    let numberRange: ClosedRange<Double>?
    let dateRange: ClosedRange<Date>?
    let colorSupportsAlpha: Bool
    let collectionReorderable: Bool
    let collectionItemTitleKey: String?
    let collectionItemIdentifierKey: String?

    init<Root: SBJStructured>(metadata: SBJPropertyMetadata<Root>?) {
      propertyInfo = metadata?.info
      presentation =
        metadata?.hints.compactMap { hint -> SBJPropertyPresentation? in
          if case .presentation(let value) = hint { return value }
          return nil
        }.first
      textStyle =
        metadata?.hints.compactMap { hint -> SBJStringStyle? in
          if case .textStyle(let style) = hint { return style }
          return nil
        }.first
      textAutocorrection =
        metadata?.hints.compactMap { hint -> SBJTextAutocorrection? in
          if case .textAutocorrection(let value) = hint { return value }
          return nil
        }.first ?? .automatic
      textCapitalization =
        metadata?.hints.compactMap { hint -> SBJTextCapitalization? in
          if case .textCapitalization(let value) = hint { return value }
          return nil
        }.first ?? .automatic
      textMaximumLength =
        metadata?.constraints.compactMap { constraint -> Int? in
          if case .textLength(_, let maximum) = constraint { return maximum }
          return nil
        }.first
      integerRange =
        metadata?.constraints.compactMap { constraint -> ClosedRange<Int>? in
          switch constraint {
          case .integerRange(let range): return range
          case .integerMinimum(let minimum): return minimum...Int.max
          default: return nil
          }
        }.first
      numberRange =
        metadata?.constraints.compactMap { constraint -> ClosedRange<Double>? in
          switch constraint {
          case .numberRange(let range): return range
          case .numberMinimum(let minimum): return minimum...Double.greatestFiniteMagnitude
          default: return nil
          }
        }.first
      dateRange =
        metadata?.constraints.compactMap { constraint -> ClosedRange<Date>? in
          if case .dateRange(let range) = constraint { return range }
          return nil
        }.first
      colorSupportsAlpha =
        metadata?.hints.compactMap { hint -> Bool? in
          if case .colorSupportsAlpha(let value) = hint { return value }
          return nil
        }.first ?? true
      collectionReorderable =
        metadata?.hints.compactMap { hint -> Bool? in
          if case .reorderable(let value) = hint { return value }
          return nil
        }.first ?? true
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
  /// Use the root/key-path initializer for a property on an `SBJSwiftUIEditable`
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
      presentation: SBJPropertyPresentation? = nil,
      textStyle: SBJStringStyle? = nil,
      textMaximumLength: Int? = nil,
      integerRange: ClosedRange<Int>? = nil,
      numberRange: ClosedRange<Double>? = nil,
      dateRange: ClosedRange<Date>? = nil,
      colorSupportsAlpha: Bool = true,
      collectionReorderable: Bool = true
    ) {
      render = {
        SBJValueEditor.makeView(
          label: label,
          value: value,
          registry: registry,
          presentation: presentation,
          textStyle: textStyle,
          textMaximumLength: textMaximumLength,
          integerRange: integerRange,
          numberRange: numberRange,
          dateRange: dateRange,
          colorSupportsAlpha: colorSupportsAlpha,
          collectionReorderable: collectionReorderable
        )
      }
    }

    /// Creates a model-aware editor for one structured property.
    ///
    /// The label and presentation configuration are read from the property's
    /// generated structural metadata. Exact-key-path bindings and whole-line
    /// replacements registered in `registry` are honored as well.
    public init<Root: SBJSwiftUIEditable>(
      root: Binding<Root>,
      keyPath: WritableKeyPath<Root, Value>,
      originalRoot: Root? = nil,
      registry: SBJEditorRegistry = .init()
    ) where Value: Codable {
      let metadata = Root.propertyMetadata(for: keyPath)
      let label =
        metadata?.displayName
        ?? Root.sbjEditableFields.first(where: { ($0.keyPath as AnyKeyPath) == (keyPath as AnyKeyPath) })?.name
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

    init<Root: SBJSwiftUIEditable>(
      root: Binding<Root>,
      originalRoot: Root?,
      keyPath: WritableKeyPath<Root, Value>,
      label: String,
      propertyName: String,
      registry: SBJEditorRegistry,
      configuration: SBJEditFieldConfiguration,
      focusRequest: SBJEditorFocusRequest?,
      labelIsUnknown: Bool,
      context: SBJEditTraversalContext
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
          presentation: configuration.presentation,
          textStyle: configuration.textStyle,
          textMaximumLength: configuration.textMaximumLength,
          integerRange: configuration.integerRange,
          numberRange: configuration.numberRange,
          dateRange: configuration.dateRange,
          colorSupportsAlpha: configuration.colorSupportsAlpha,
          collectionReorderable: configuration.collectionReorderable,
          collectionItemTitleKey: configuration.collectionItemTitleKey,
          collectionItemIdentifierKey: configuration.collectionItemIdentifierKey,
          focusRequest: focusRequest,
          labelIsUnknown: labelIsUnknown,
          context: context
        )
        let content =
          registry.customLineItem(
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
          SBJEditorPropertyInfoContainer(
            content: content,
            propertyName: propertyName,
            info: configuration.propertyInfo
          )
          .sbjTextInputPolicies(
            autocorrection: configuration.textAutocorrection,
            capitalization: configuration.textCapitalization
          )
          .environment(\.sbjEditorVisuallyIneffective, visuallyIneffective)
          .sbjEditorNavigationAnchor(for: context.navigationPath)
        )
      }
    }

    init<Root: SBJSwiftUIEditable>(
      editorOnlyRoot root: Binding<Root>,
      originalRoot: Root?,
      keyPath: WritableKeyPath<Root, Value>,
      label: String,
      registry: SBJEditorRegistry,
      focusRequest: SBJEditorFocusRequest?,
      labelIsUnknown: Bool,
      context: SBJEditTraversalContext
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
          context: context
        )
        let content =
          registry.customLineItem(
            keyPath: keyPath,
            label: label,
            binding: value,
            defaultContent: defaultContent
          ) ?? defaultContent
        return AnyView(
          SBJEditorPropertyInfoContainer(content: content, propertyName: label, info: nil)
            .sbjEditorNavigationAnchor(for: context.navigationPath)
        )
      }
    }

    public var body: some View {
      render()
    }
  }
#endif
