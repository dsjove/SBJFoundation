import SBJStructure
import SBJUIVocabulary
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
  /// The descriptor consumes canonical metadata and owns automatic-editor concerns such
  /// as search/filtering, validation state, and type erasure; actual field rendering
  /// is delegated to `SBJEditField`.
  @MainActor
  public struct SBJEditorPropertyDescriptor<Root: SBJMutableStructure> {
    public let name: String
    let traversalDisclosureMode: SBJPresentationDisclosureMode
    let isTraversalDisclosure: Bool
    public let metadata: SBJPropertyMetadata<Root>
    private let makeView:
      (
        Binding<Root>, Root?, SBJEditorRegistry, String?, SBJEditorFocusRequest?, Bool,
        SBJEditTraversalContext, Bool
      ) -> AnyView
    private let collectIssues: (Root, [String], SBJEditorRegistry) -> [SBJEditorCapabilityIssue]
    private let traverseChildren: (Root, SBJEditTraversalContext) -> [SBJEditorTraversalNode]
    private let traverseBoundChildren: (Binding<Root>, Root?, SBJEditorRegistry, SBJEditTraversalContext) -> [SBJEditorTraversalNode]

    init<Value>(
      metadata: SBJPropertyMetadata<Root>,
      keyPath: WritableKeyPath<Root, Value>,
      disclosureMode: SBJPresentationDisclosureMode = .closed
    ) {
      let name = metadata.displayName
      self.name = name
      self.traversalDisclosureMode = disclosureMode
      self.isTraversalDisclosure = !(Value.self is any SBJTypedEditorValue.Type) &&
        (Value.self is any SBJMutableStructure.Type
        || Value.self is any SBJEditorTraversableValue.Type
        || Value.self is any SBJStructuredEnum.Type)
      self.metadata = metadata
      let configuration = SBJEditFieldConfiguration(metadata: metadata)

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
          itemIdentifierKey: configuration.collectionItemIdentifierKey,
          elementPresentation: configuration.collectionElementPresentation
        )
      }
      self.traverseBoundChildren = { root, originalRoot, registry, context in
        SBJEditorValueTraversal.boundChildren(
          of: root[dynamicMember: keyPath],
          originalValue: originalRoot?[keyPath: keyPath],
          context: context,
          registry: registry,
          itemTitleKey: configuration.collectionItemTitleKey,
          itemIdentifierKey: configuration.collectionItemIdentifierKey,
          elementPresentation: configuration.collectionElementPresentation,
          dictionaryPresentation: configuration.dictionaryPresentation,
          constraints: configuration.constraintProjection,
          reorderable: configuration.collectionReorderable,
          removable: configuration.collectionRemovable,
          insertable: configuration.collectionInsertable
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

    /// Read-only properties use their canonical metadata and never create a writable binding.
    init<Value>(metadata: SBJPropertyMetadata<Root>, readOnly keyPath: KeyPath<Root, Value>) {
      let name = metadata.displayName
      self.name = name
      self.metadata = metadata
      self.traversalDisclosureMode = .closed
      self.isTraversalDisclosure = false
      self.makeView = { root, _, _, overrideName, _, _, context, _ in
        AnyView(
          SBJEditorNomenclatureContainer(
            content: AnyView(SBJEditorRow(context: context) {
              HStack(alignment: .firstTextBaseline) {
                Text(overrideName ?? name)
                Spacer(minLength: 8)
                Text(SBJEditorReadOnlyValue.text(root.wrappedValue[keyPath: keyPath], hints: metadata.hints, constraints: metadata.constraints))
                  .foregroundStyle(.secondary)
                  .textSelection(.enabled)
              }
            }), propertyName: name, info: metadata.info,
            caseInfo: { SBJEditorEnumCaseInformation.info(for: root.wrappedValue[keyPath: keyPath]) },
            branch: context.branch
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
                          registry: registry, criteria: criteria,
                          showsReadOnlyProperties: context.branch.showsReadOnlyProperties)
        },
        children: { [traverseBoundChildren] projectedContext in
          traverseBoundChildren(root, originalRoot, registry, projectedContext)
        }
      )
    }

    private func hasChanged(in root: Root, from originalRoot: Root?) -> Bool {
      // Derived values can change even when no stored state changes (for example, age).
      guard metadata.storage == .stored else { return false }
      guard let originalRoot else { return true }
      return !metadata.structurallyEquals(in: root, originalRoot)
    }

    func containsEmptyContent(
      root: Root,
      registry: SBJEditorRegistry
    ) -> Bool {
      metadata.containsEmptyContent(
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
      criteria: SBJStructuralSearchCriteria,
      showsReadOnlyProperties: Bool = false
    ) -> Bool {
      criteria.includes(
        isChanged: hasChanged(in: root, from: originalRoot),
        containsEmptyContent: containsEmptyContent(root: root, registry: registry),
        matchesSearch: { query in
          SBJEditorSearchMatcher.matches(label: name, value: metadata.value(in: root), query: query,
                                        showsReadOnlyProperties: showsReadOnlyProperties)
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
      let changed = hasChanged(in: root.wrappedValue, from: originalRoot)
      let contentState = metadata.hasContent(in: root.wrappedValue)
      let rootValidationError = rootValidation.resolving(root.wrappedValue)
      let invalid =
        (metadata.validationError(in: root.wrappedValue) != nil
          || (rootValidationError?.keyPath.contains(property: metadata.keyPath) == true))
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
            SBJEditorSearchMatcher.matches(label: name, value: metadata.value(in: root.wrappedValue), query: query,
                                           showsReadOnlyProperties: context.branch.showsReadOnlyProperties)
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
