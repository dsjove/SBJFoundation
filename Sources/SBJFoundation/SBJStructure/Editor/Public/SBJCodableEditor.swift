#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// The reflected editor content without search controls or a scrolling container.
///
/// The host owns layout and scrolling. Pair this with ``SBJEditorSearchView``
/// when the stock search/filter UI is desired.
public struct SBJEditorView<Value: SBJSwiftUIEditable>: View {
    @Binding private var value: Value
    private let presentationModel: SBJEditorPresentationModel
    private let registry: SBJEditorRegistry
    @State private var originalValue: Value

    public init(
        value: Binding<Value>,
        presentationModel: SBJEditorPresentationModel,
        registry: SBJEditorRegistry = .init()
    ) {
        self._value = value
        self.presentationModel = presentationModel
        self.registry = registry
        self._originalValue = State(initialValue: value.wrappedValue.sbjCodableCopy())
    }

    private var rootSnapshot: [SBJEditorSnapshotItem<SBJEditorPropertyDescriptor<Value>>] {
        SBJEditorPerformanceDiagnostics.measure("Editor Root Snapshot") {
            Value.sbjEditorFields.enumerated().compactMap { offset, field in
            let navigationPath = [field.name]
            guard presentationModel.navigationTarget?.contains(navigationPath) == true || field.isIncluded(
                root: value,
                originalRoot: originalValue,
                registry: registry,
                criteria: presentationModel.searchCriteria
            ) else { return nil }
            return SBJEditorSnapshotItem(
                itemIdentifier: SBJEditorItemIdentifier.root.appending("property:\(field.name)"),
                indexPath: SBJEditorIndexPath.root.appending("field:\(offset)"),
                content: field
            )
            }
        }
    }

    private var rootRows: [SBJEditorPresentationRow<SBJEditorPropertyDescriptor<Value>>] {
        sbjEditorPresentationRows(
            from: rootSnapshot,
            parent: .root,
            navigationPath: { $0.name },
            depthIncrement: 0
        )
    }

    /// Project only the exposed nodes; closed branches never construct child
    /// descriptors or SwiftUI views. The host owns the scrolling container.
    private var flatRows: [SBJEditorTraversalNode] {
        SBJEditorPerformanceDiagnostics.measure("Editor Flat Projection") {
            sbjEditorFlatRows(
                roots: Value._sbjBoundRootNodes(
                    binding: $value,
                    originalValue: originalValue,
                    registry: registry
                ),
                presentationModel: presentationModel
            )
        }
    }

    public var body: some View {
        let projectedRows = flatRows
        let canUseFlatRenderer = !SBJEditorPerformanceDiagnostics.isProjectionAuditEnabled
            || sbjAuditFlatRows(projectedRows).canUseIndependentFlatRenderer

        Group {
            if canUseFlatRenderer {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(projectedRows) { row in
                        if let rendered = row.renderedRow() {
                            rendered
                                .sbjEditorNavigationAnchor(for: row.context.navigationPath)
                                .id(row.id)
                        }
                    }
                }
            } else {
                let rootValidation = SBJEditorPerformanceDiagnostics.measure("Editor Root Validation") {
                    SBJEditorRootValidationResult.computed(
                        SBJInvariantCheck.validationError(
                            value,
                            at: SBJValidationKeyPath(\Value.self)
                        )
                    )
                }
                // Never render a recursive container alongside its projected
                // descendants. Keep the last working editor for unsupported
                // descriptors until all compound cases are independently atomic.
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(rootRows) { row in
                        row.content.view(
                            root: $value,
                            originalRoot: originalValue,
                            registry: registry,
                            context: row.context,
                            rootValidation: rootValidation,
                            applyFiltering: false
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(presentationModel)
        .environment(\.sbjEditorSearchCriteria, presentationModel.searchCriteria)
        .environment(\.sbjEditorNavigationTarget, presentationModel.navigationTarget)
        .environment(\.sbjEditorShowIssues, {
            presentationModel.isShowingIssues = true
        })
        .environment(\.sbjEditorValidationStateChanged, { isInvalid in
            if isInvalid {
                // A row has already done the validation work. We know there is
                // at least one issue, so make the issue control visible without
                // traversing the model again.
                presentationModel.hasIssues = true
            } else {
                // Resolving one row does not tell us whether another issue still
                // exists. Ask the search/issue presenter to recompute before it
                // considers hiding the control.
                presentationModel.issueResolutionRevision &+= 1
            }
        })
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }
}

/// Stock search/filter controls for an ``SBJEditorView``.
///
/// This view deliberately does not own scrolling or editor content. Place it
/// wherever the client wants the controls to remain visible.
public struct SBJEditorSearchView<Value: SBJSwiftUIEditable>: View {
    private let value: Value
    private let presentationModel: SBJEditorPresentationModel
    private let registry: SBJEditorRegistry
    @State private var cachedIssues: [SBJEditorIssue]?
    @State private var draftSearchText: String

    public init(
        value: Value,
        presentationModel: SBJEditorPresentationModel,
        registry: SBJEditorRegistry = .init()
    ) {
        self.value = value
        self.presentationModel = presentationModel
        self.registry = registry
        self._cachedIssues = State(initialValue: nil)
        self._draftSearchText = State(initialValue: presentationModel.searchCriteria.searchQuery)
    }

    private func refreshIssues() {
        let issues = SBJEditorDiagnostics.issues(for: value, registry: registry)
        cachedIssues = issues
        presentationModel.hasIssues = !issues.isEmpty
    }

    private func refreshIssuesAndShow() {
        refreshIssues()
        presentationModel.isShowingIssues = true
    }

    public var body: some View {
        @Bindable var model = presentationModel
        SBJEditorSearchBar(
            searchText: $draftSearchText,
            criteria: $model.searchCriteria,
            hasIssues: presentationModel.hasIssues,
            showIssues: refreshIssuesAndShow
        )
        .sheet(isPresented: $model.isShowingIssues) {
            SBJEditorIssueList(issues: cachedIssues ?? []) { issue in
                presentationModel.navigate(to: SBJEditorNavigationTarget(issuePath: issue.path))
                presentationModel.isShowingIssues = false
            }
        }
        .onAppear {
            refreshIssues()
        }
        .task(id: presentationModel.issueResolutionRevision) {
            // A field that became valid may have resolved the last issue, but
            // only a diagnostic pass can establish that no other issues remain.
            do {
                try await Task.sleep(for: .milliseconds(120))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            refreshIssues()
        }
        // Keep keystrokes local to the search control. The potentially very
        // large editor tree only sees a new query after the user pauses, rather
        // than being invalidated and laid out for every character typed.
        .task(id: draftSearchText) {
            if draftSearchText.isEmpty {
                presentationModel.searchCriteria.searchQuery = ""
                return
            }

            do {
                try await Task.sleep(for: .milliseconds(180))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            presentationModel.searchCriteria.searchQuery = draftSearchText
        }
        .onChange(of: presentationModel.searchCriteria.searchQuery) { _, newValue in
            // Preserve programmatic changes made by a host without fighting
            // ordinary typing (which already has the same value after debounce).
            if newValue != draftSearchText {
                draftSearchText = newValue
            }
        }
    }
}

/// Reusable default composition for values annotated with ``SBJStructure()``.
///
/// This convenience view keeps search and editor content together and uses
/// ``SBJEditorScrollView`` so issue navigation can reveal and scroll to a field.
/// Clients that need independent placement or a custom scrolling policy should
/// use ``SBJEditorSearchView`` and ``SBJEditorView`` directly.
public struct SBJCodableEditorCore<Value: SBJSwiftUIEditable>: View {
    @Binding private var value: Value
    private let registry: SBJEditorRegistry
    @State private var presentationModel = SBJEditorPresentationModel()

    public init(
        value: Binding<Value>,
        registry: SBJEditorRegistry = .init()
    ) {
        self._value = value
        self.registry = registry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SBJEditorSearchView(value: value, presentationModel: presentationModel, registry: registry)
            SBJEditorScrollView(presentationModel: presentationModel) {
                SBJEditorView(value: $value, presentationModel: presentationModel, registry: registry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Compatibility wrapper around ``SBJCodableEditorCore``.
public struct SBJCodableEditor<Value: SBJSwiftUIEditable>: View {
    @Binding private var value: Value
    private let registry: SBJEditorRegistry

    public init(
        _ title: String? = nil,
        value: Binding<Value>,
        registry: SBJEditorRegistry = .init()
    ) {
        self._value = value
        self.registry = registry
    }

    public var body: some View {
        SBJCodableEditorCore(value: $value, registry: registry)
    }
}
#endif
