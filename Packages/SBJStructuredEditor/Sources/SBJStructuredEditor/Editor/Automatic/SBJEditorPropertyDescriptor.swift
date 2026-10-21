import SBJDataDefinition
import SBJUIVocabulary
import SBJUnits
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
  /// `@SBJEditable` emits this type into client code, so it must remain public even
  /// though applications normally use ``SBJEditField`` rather than constructing
  /// editor properties directly. The descriptor owns automatic-editor concerns such
  /// as search/filtering, validation state, and type erasure; actual field rendering
  /// is delegated to `SBJEditField`.
  @MainActor
  public struct SBJEditorPropertyDescriptor<Root: SBJSwiftUIEditable> {
    public let name: String
    let traversalDisclosureMode: SBJEditorDisclosureMode
    let isTraversalDisclosure: Bool
    public let editableField: SBJMutableProperty<Root>
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
      self.isTraversalDisclosure = Value.self is any SBJSwiftUIEditable.Type
        || Value.self is any SBJEditorTraversableValue.Type
        || Value.self is any SBJEditableAssociatedEnum.Type
      let editableField = SBJMutableProperty<Root>(name: name, keyPath)
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
            context: context.withBranch(context.branch.withDisclosureMode(disclosureMode)),
            headerOnly: headerOnly
          )
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
      nonStructuralName name: String,
      _ keyPath: WritableKeyPath<Root, Value>
    ) {
      self.name = name
      self.traversalDisclosureMode = .closed
      self.isTraversalDisclosure = false
      self.editableField = SBJMutableProperty<Root>(nonStructuralName: name, keyPath)
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
        isDisclosure: isTraversalDisclosure,
        children: { [traverseChildren] projectedContext in
          traverseChildren(root, projectedContext)
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
        isDisclosure: isTraversalDisclosure,
        render: { [self] renderedContext in
          view(root: root, originalRoot: originalRoot, registry: registry,
               context: renderedContext,
               applyFiltering: false, headerOnly: true)
        },
        isIncluded: { [self] criteria in
          self.isIncluded(root: root.wrappedValue, originalRoot: originalRoot,
                          registry: registry, criteria: criteria)
        },
        children: { [traverseBoundChildren] projectedContext in
          traverseBoundChildren(root, originalRoot, registry, projectedContext)
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
      criteria: SBJStructuralSearchCriteria
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
      let rowContext = context.withBranch(context.branch.withStatus(
        SBJEditorRowStatus(isChanged: changed, hasContent: contentState, isInvalid: invalid)
      ))
      let rendered = makeView(root, originalRoot, registry, nameOverride, focusRequest, labelIsUnknown, rowContext, headerOnly)
        .accessibilityIdentifier(context.itemIdentifier.description)

      if !applyFiltering {
        return AnyView(rendered.id(context.itemIdentifier))
      }

      return AnyView(
        SBJEditorFilteredView(
          content: { AnyView(rendered) },
          isChanged: changed,
          matchesSearch: { query in
            editableField.matchesSearch(in: root.wrappedValue, query: query)
          },
          containsEmptyContent: {
            containsEmptyContent(root: root.wrappedValue, registry: registry)
          },
          navigationPath: context.navigationPath,
          searchCriteria: context.branch.searchCriteria
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
    let searchCriteria: SBJStructuralSearchCriteria
    @Environment(SBJEditorPresentationModel.self) private var sbjNavigationModel: SBJEditorPresentationModel?
    private var navigationTarget: SBJEditorNavigationTarget? { sbjNavigationModel?.navigationTarget }

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
