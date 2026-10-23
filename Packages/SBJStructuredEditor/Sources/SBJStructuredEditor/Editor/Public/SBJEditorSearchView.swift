#if !os(tvOS) && !os(watchOS)
import SwiftUI
import SBJFileResources
import SBJUIVocabulary
import SBJUnits

public extension SBJBundledContentReference {
    static var structuredEditorSearch: SBJBundledContentReference {
        .help("Structure Editor Search", resourceName: "SBJStructureEditorSearch", bundle: .module)
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
#endif
