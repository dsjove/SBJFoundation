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
    private let documentID: String?
    private let options: SBJEditorOptions
    @State private var originalValue: Value

    /// Pass a stable logical document ID when this view can switch documents
    /// without being removed from the SwiftUI hierarchy. Changing it resets
    /// the baseline used by changed-only presentation; ordinary edits do not.
    public init(
        value: Binding<Value>,
        presentationModel: SBJEditorPresentationModel,
        registry: SBJEditorRegistry = .init(),
        documentID: String? = nil,
        options: SBJEditorOptions = .init()
    ) {
        self._value = value
        self.documentID = documentID
        self.options = options
        self.presentationModel = presentationModel
        self.registry = registry
        self._originalValue = State(initialValue: value.wrappedValue.sbjCodableCopy())
    }

    /// Project only the exposed nodes; closed branches never construct child
    /// descriptors or SwiftUI views. The host owns the scrolling container.
    private var editorRows: [SBJEditorTraversalNode] {
        SBJEditorPerformanceDiagnostics.measure("Editor Row Projection") {
            sbjEditorRows(
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
        let rows = editorRows
        return LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 8) {
                    if let rendered = row.renderedRow() {
                        rendered
                            .sbjEditorNavigationAnchor(for: row.context.navigationPath)
                    }
                    ForEach(Array(row.endDividerLevels.enumerated()), id: \.offset) { entry in
                        SBJEditorGroupEnd(indentLevel: entry.element)
                    }
                }
                .id(row.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(presentationModel)
        .onChange(of: documentID) { _, _ in
            // A different logical document starts a new comparison baseline.
            // Edits within one document must not reset this snapshot.
            originalValue = value.sbjCodableCopy()
        }
        .transaction { transaction in
            if !options.animationsEnabled {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
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
    @State private var draftSearchText: String
    // Distinguishes our debounced commits from programmatic model updates.
    @State private var lastCommittedSearchText: String

    public init(
        value: Value,
        presentationModel: SBJEditorPresentationModel,
        registry: SBJEditorRegistry = .init()
    ) {
        self.value = value
        self.presentationModel = presentationModel
        self.registry = registry
        self._draftSearchText = State(initialValue: presentationModel.searchCriteria.searchQuery)
        self._lastCommittedSearchText = State(initialValue: presentationModel.searchCriteria.searchQuery)
    }

    private func refreshIssues() {
        let issues = SBJEditorDiagnostics.issues(for: value, registry: registry)
        presentationModel.replaceIssues(issues)
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
            SBJEditorIssueList(issues: presentationModel.issues ?? []) { issue in
                presentationModel.navigate(to: SBJEditorNavigationTarget(issuePath: issue.path))
                presentationModel.isShowingIssues = false
            }
        }
        .task(id: presentationModel.issueResolutionRevision) {
            // The first pass is immediate. Later invalidations are coalesced
            // so many row-validation changes cause only one diagnostic pass.
            if presentationModel.issues != nil {
                do {
                    try await Task.sleep(for: .milliseconds(120))
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            refreshIssues()
        }
        // Keep keystrokes local to the search control. The potentially very
        // large editor tree only sees a new query after the user pauses, rather
        // than being invalidated and laid out for every character typed.
        .task(id: draftSearchText) {
            let query = draftSearchText
            if !query.isEmpty {
                do {
                    try await Task.sleep(for: .milliseconds(180))
                } catch {
                    return
                }
            }
            guard !Task.isCancelled, query == draftSearchText else { return }
            guard query != presentationModel.searchCriteria.searchQuery else { return }
            lastCommittedSearchText = query
            presentationModel.searchCriteria.searchQuery = query
        }
        .onChange(of: presentationModel.searchCriteria.searchQuery) { _, newValue in
            // Ignore the echo of our own debounced commit: the user may
            // already have typed something newer by the time this fires.
            guard newValue != lastCommittedSearchText else { return }
            lastCommittedSearchText = newValue
            draftSearchText = newValue
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
    private let options: SBJEditorOptions
    @State private var presentationModel = SBJEditorPresentationModel()

    public init(
        value: Binding<Value>,
        registry: SBJEditorRegistry = .init(),
        options: SBJEditorOptions = .init()
    ) {
        self._value = value
        self.registry = registry
        self.options = options
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SBJEditorSearchView(value: value, presentationModel: presentationModel, registry: registry)
            SBJEditorScrollView(presentationModel: presentationModel) {
                SBJEditorView(value: $value, presentationModel: presentationModel, registry: registry, options: options)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Compatibility wrapper around ``SBJCodableEditorCore``.
public struct SBJCodableEditor<Value: SBJSwiftUIEditable>: View {
    @Binding private var value: Value
    private let registry: SBJEditorRegistry
    private let options: SBJEditorOptions

    public init(
        _ title: String? = nil,
        value: Binding<Value>,
        registry: SBJEditorRegistry = .init(),
        options: SBJEditorOptions = .init()
    ) {
        self._value = value
        self.registry = registry
        self.options = options
    }

    public var body: some View {
        SBJCodableEditorCore(value: $value, registry: registry, options: options)
    }
}
#endif
