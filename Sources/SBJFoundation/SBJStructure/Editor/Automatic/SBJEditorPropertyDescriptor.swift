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

  /// Type-erased property descriptor used by the generated SwiftUI editor.
  ///
  /// `@SBJStructure` emits this type into client code, so it must remain public even
  /// though applications normally use ``SBJEditField`` rather than constructing
  /// editor properties directly. The descriptor owns automatic-editor concerns such
  /// as search/filtering, validation state, and type erasure; actual field rendering
  /// is delegated to `SBJEditField`.
  @MainActor
  public struct SBJEditorPropertyDescriptor<Root: SBJSwiftUIEditable> {
    public let name: String
    public let editableField: SBJEditableField<Root>
    private let makeView:
      (
        Binding<Root>, Root?, SBJEditorRegistry, String?, SBJEditorFocusRequest?, Bool,
        SBJEditTraversalContext
      ) -> AnyView
    private let collectIssues: (Root, [String], SBJEditorRegistry) -> [SBJEditorCapabilityIssue]

    public init<Value: Codable>(
      name: String,
      _ keyPath: WritableKeyPath<Root, Value>
    ) {
      self.name = name
      let editableField = SBJEditableField<Root>(name: name, keyPath)
      self.editableField = editableField
      let configuration = SBJEditFieldConfiguration(metadata: editableField.structuralMetadata)

      self.makeView = {
        root, originalRoot, registry, overrideName, focusRequest, labelIsUnknown, context in
        AnyView(
          SBJEditField(
            root: root,
            originalRoot: originalRoot,
            keyPath: keyPath,
            label: overrideName ?? name,
            propertyName: name,
            registry: registry,
            configuration: configuration,
            focusRequest: focusRequest,
            labelIsUnknown: labelIsUnknown,
            context: context
          )
        )
      }
      self.collectIssues = { root, path, registry in
        SBJValueEditor.collectIssues(
          value: root[keyPath: keyPath],
          path: path + [name],
          registry: registry,
          collectionItemTitleKey: configuration.collectionItemTitleKey
        )
      }
    }

    /// Creates an editor property intentionally outside `Root`'s structural
    /// metadata. `Value` does not need to be `Codable`; the application may
    /// provide an exact-type editor through `SBJEditorRegistry`.
    public init<Value>(
      editorOnlyName name: String,
      _ keyPath: WritableKeyPath<Root, Value>
    ) {
      self.name = name
      self.editableField = SBJEditableField<Root>(editorOnlyName: name, keyPath)
      self.makeView = {
        root, originalRoot, registry, overrideName, focusRequest, labelIsUnknown, context in
        AnyView(
          SBJEditField(
            editorOnlyRoot: root,
            originalRoot: originalRoot,
            keyPath: keyPath,
            label: overrideName ?? name,
            registry: registry,
            focusRequest: focusRequest,
            labelIsUnknown: labelIsUnknown,
            context: context
          )
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
      let invalid =
        editableField.participatesInStructuralValidation
        && (editableField.validationError(in: root.wrappedValue) != nil
          || (rootValidationError?.keyPath.contains(property: editableField.keyPath) == true))
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
      if navigationTarget?.contains(navigationPath) == true
        || searchCriteria.includes(
          isChanged: isChanged,
          containsEmptyContent: containsEmptyContent(),
          matchesSearch: matchesSearch
        )
      {
        content()
      }
    }
  }
#endif
