#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Shared presentation state for the stock SwiftUI structured editor.
///
/// Keep this state in the client when hosting ``SBJEditorSearchView`` and
/// ``SBJEditorView`` separately. That lets the client choose its own scrolling,
/// form, toolbar, sheet, or inspector layout while both views share filters and
/// issue presentation.
public struct SBJEditorViewState: Equatable, Sendable {
    public var searchCriteria: SBJEditSearchCriteria
    public var isShowingIssues: Bool
    public internal(set) var navigationTarget: SBJEditorNavigationTarget?
    var hasIssues: Bool? = nil
    var issueResolutionRevision: UInt = 0
    var navigationRevision: UInt = 0

    public init(
        searchCriteria: SBJEditSearchCriteria = .init(),
        isShowingIssues: Bool = false,
        navigationTarget: SBJEditorNavigationTarget? = nil
    ) {
        self.searchCriteria = searchCriteria
        self.isShowingIssues = isShowingIssues
        self.navigationTarget = navigationTarget
    }

    public mutating func navigate(to target: SBJEditorNavigationTarget) {
        navigationTarget = target
        navigationRevision &+= 1
    }
}

/// The reflected editor content without search controls or a scrolling container.
///
/// The host owns layout and scrolling. Pair this with ``SBJEditorSearchView``
/// when the stock search/filter UI is desired.
public struct SBJEditorView<Value: SBJSwiftUIEditable>: View {
    @Binding private var value: Value
    @Binding private var state: SBJEditorViewState
    private let registry: SBJEditorRegistry
    @State private var originalValue: Value

    public init(
        value: Binding<Value>,
        state: Binding<SBJEditorViewState>,
        registry: SBJEditorRegistry = .init()
    ) {
        self._value = value
        self._state = state
        self.registry = registry
        self._originalValue = State(initialValue: value.wrappedValue.sbjCodableCopy())
    }

    private var rootSnapshot: [SBJEditorSnapshotItem<SBJEditorPropertyDescriptor<Value>>] {
        Value.sbjEditorFields.enumerated().compactMap { offset, field in
            let navigationPath = [field.name]
            guard state.navigationTarget?.contains(navigationPath) == true || field.isIncluded(
                root: value,
                originalRoot: originalValue,
                registry: registry,
                criteria: state.searchCriteria
            ) else { return nil }
            return SBJEditorSnapshotItem(
                itemIdentifier: SBJEditorItemIdentifier.root.appending("property:\(field.name)"),
                indexPath: SBJEditorIndexPath.root.appending("field:\(offset)"),
                content: field
            )
        }
    }

    public var body: some View {
        let rootValidation = SBJEditorRootValidationResult.computed(
            SBJInvariantCheck.validationError(
                value,
                at: SBJValidationKeyPath(\Value.self)
            )
        )

        VStack(alignment: .leading, spacing: 8) {
            ForEach(rootSnapshot) { item in
                let field = item.content
                field.view(
                    root: $value,
                    originalRoot: originalValue,
                    registry: registry,
                    context: SBJEditTraversalContext(
                        treeLevel: 0,
                        itemIdentifier: item.itemIdentifier,
                        indexPath: item.indexPath,
                        navigationPath: [field.name]
                    ),
                    rootValidation: rootValidation,
                    applyFiltering: false
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.sbjEditorSearchCriteria, state.searchCriteria)
        .environment(\.sbjEditorNavigationTarget, state.navigationTarget)
        .environment(\.sbjEditorShowIssues, {
            state.isShowingIssues = true
        })
        .environment(\.sbjEditorValidationStateChanged, { isInvalid in
            if isInvalid {
                // A row has already done the validation work. We know there is
                // at least one issue, so make the issue control visible without
                // traversing the model again.
                state.hasIssues = true
            } else {
                // Resolving one row does not tell us whether another issue still
                // exists. Ask the search/issue presenter to recompute before it
                // considers hiding the control.
                state.issueResolutionRevision &+= 1
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
    @Binding private var state: SBJEditorViewState
    private let registry: SBJEditorRegistry
    @State private var cachedIssues: [SBJEditorIssue]?
    @State private var draftSearchText: String

    public init(
        value: Value,
        state: Binding<SBJEditorViewState>,
        registry: SBJEditorRegistry = .init()
    ) {
        self.value = value
        self._state = state
        self.registry = registry
        self._cachedIssues = State(initialValue: nil)
        self._draftSearchText = State(initialValue: state.wrappedValue.searchCriteria.searchQuery)
    }

    private func refreshIssues() {
        let issues = SBJEditorDiagnostics.issues(for: value, registry: registry)
        cachedIssues = issues
        state.hasIssues = !issues.isEmpty
    }

    private func refreshIssuesAndShow() {
        refreshIssues()
        state.isShowingIssues = true
    }

    public var body: some View {
        SBJEditorSearchBar(
            searchText: $draftSearchText,
            criteria: $state.searchCriteria,
            hasIssues: state.hasIssues,
            showIssues: refreshIssuesAndShow
        )
        .sheet(isPresented: $state.isShowingIssues) {
            SBJEditorIssueList(issues: cachedIssues ?? []) { issue in
                state.navigate(to: SBJEditorNavigationTarget(issuePath: issue.path))
                state.isShowingIssues = false
            }
        }
        .onAppear {
            refreshIssues()
        }
        .task(id: state.issueResolutionRevision) {
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
                state.searchCriteria.searchQuery = ""
                return
            }

            do {
                try await Task.sleep(for: .milliseconds(180))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            state.searchCriteria.searchQuery = draftSearchText
        }
        .onChange(of: state.searchCriteria.searchQuery) { _, newValue in
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
    @State private var state = SBJEditorViewState()

    public init(
        value: Binding<Value>,
        registry: SBJEditorRegistry = .init()
    ) {
        self._value = value
        self.registry = registry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SBJEditorSearchView(value: value, state: $state, registry: registry)
            SBJEditorScrollView(state: $state) {
                SBJEditorView(value: $value, state: $state, registry: registry)
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
