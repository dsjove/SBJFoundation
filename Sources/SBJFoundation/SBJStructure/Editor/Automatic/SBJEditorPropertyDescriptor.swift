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
    let traversalDisclosureMode: SBJEditorDisclosureMode
    public let editableField: SBJEditableField<Root>
    private let makeView:
      (
        Binding<Root>, Root?, SBJEditorRegistry, String?, SBJEditorFocusRequest?, Bool,
        SBJEditTraversalContext, Bool
      ) -> AnyView
    private let collectIssues: (Root, [String], SBJEditorRegistry) -> [SBJEditorCapabilityIssue]
    private let traverseChildren: (Root, SBJEditTraversalContext) -> [SBJEditorTraversalNode]
    private let traverseBoundChildren: (Binding<Root>, Root?, SBJEditorRegistry, SBJEditTraversalContext) -> [SBJEditorTraversalNode]

    public init<Value: Codable>(
      name: String,
      _ keyPath: WritableKeyPath<Root, Value>,
      disclosureMode: SBJEditorDisclosureMode = .closed
    ) {
      self.name = name
      self.traversalDisclosureMode = disclosureMode
      let editableField = SBJEditableField<Root>(name: name, keyPath)
      self.editableField = editableField
      let configuration = SBJEditFieldConfiguration(metadata: editableField.structuralMetadata)

      self.makeView = {
        root, originalRoot, registry, overrideName, focusRequest, labelIsUnknown, context, headerOnly in
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
            context: context,
            headerOnly: headerOnly
          )
          .environment(\.sbjEditorDisclosureMode, disclosureMode)
        )
      }
      self.traverseChildren = { root, context in
        SBJEditorValueTraversal.children(
          of: root[keyPath: keyPath],
          context: context,
          itemTitleKey: configuration.collectionItemTitleKey,
          itemIdentifierKey: configuration.collectionItemIdentifierKey
        )
      }
      self.traverseBoundChildren = { root, originalRoot, registry, context in
        SBJEditorValueTraversal.boundChildren(
          of: root[dynamicMember: keyPath],
          originalValue: originalRoot?[keyPath: keyPath],
          context: context,
          registry: registry,
          itemTitleKey: configuration.collectionItemTitleKey,
          itemIdentifierKey: configuration.collectionItemIdentifierKey
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
      self.traversalDisclosureMode = .closed
      self.editableField = SBJEditableField<Root>(editorOnlyName: name, keyPath)
      self.makeView = {
        root, originalRoot, registry, overrideName, focusRequest, labelIsUnknown, context, headerOnly in
        AnyView(
          SBJEditField(
            editorOnlyRoot: root,
            originalRoot: originalRoot,
            keyPath: keyPath,
            label: overrideName ?? name,
            registry: registry,
            focusRequest: focusRequest,
            labelIsUnknown: labelIsUnknown,
            context: context,
            headerOnly: headerOnly
          )
        )
      }
      self.traverseChildren = { _, _ in [] }
      self.traverseBoundChildren = { _, _, _, _ in [] }
      self.collectIssues = { _, _, _ in [] }
    }

    /// A render-independent logical traversal node. The generic property's
    /// child enumeration is deferred until the caller requests it.
    func traversalNode(root: Root, context: SBJEditTraversalContext) -> SBJEditorTraversalNode {
      SBJEditorTraversalNode(
        context: context,
        name: name,
        disclosureMode: traversalDisclosureMode,
        children: { [traverseChildren] in
          traverseChildren(root, context)
        }
      )
    }

    /// A live row descriptor. Render closures retain the *binding*, not a
    /// snapshot of the value, so lazily created rows edit the current model.
    func boundTraversalNode(
      root: Binding<Root>,
      originalRoot: Root? = nil,
      registry: SBJEditorRegistry,
      context: SBJEditTraversalContext
    ) -> SBJEditorTraversalNode {
      SBJEditorTraversalNode(
        context: context,
        name: name,
        disclosureMode: traversalDisclosureMode,
        render: { [self] in
          view(root: root, originalRoot: originalRoot, registry: registry,
               context: context, applyFiltering: false, headerOnly: true)
        },
        renderingScope: .atomic,
        isIncluded: { [self] criteria in
          self.isIncluded(root: root.wrappedValue, originalRoot: originalRoot,
                          registry: registry, criteria: criteria)
        },
        children: { [traverseBoundChildren] in
          traverseBoundChildren(root, originalRoot, registry, context)
        }
      )
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
      applyFiltering: Bool = true,
      headerOnly: Bool = false
    ) -> AnyView {
      let changed = editableField.hasChanged(in: root.wrappedValue, from: originalRoot)
      let contentState = editableField.hasContent(in: root.wrappedValue)
      let rootValidationError = rootValidation.resolving(root.wrappedValue)
      let invalid =
        editableField.participatesInStructuralValidation
        && (editableField.validationError(in: root.wrappedValue) != nil
          || (rootValidationError?.keyPath.contains(property: editableField.keyPath) == true))
      let rendered = AnyView(
        makeView(root, originalRoot, registry, nameOverride, focusRequest, labelIsUnknown, context, headerOnly)
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
