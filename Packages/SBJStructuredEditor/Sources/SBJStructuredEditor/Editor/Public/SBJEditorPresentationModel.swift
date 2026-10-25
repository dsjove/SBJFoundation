import SBJDataDefinition
import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import Observation
import SwiftUI

/// Shared presentation state for one structured editor tree, independent of row lifetimes.
/// Owns root search/navigation/issue state and user disclosure preferences.
/// Child-specific search traversal is still derived locally and is not stored here.
@MainActor
@Observable
public final class SBJEditorPresentationModel {
    public var searchCriteria: SBJStructuralSearchCriteria
    public var formattingOptions: SBJEditorFormattingOptions
    public let expansionOptions: SBJEditorExpansionOptions

    public var isShowingIssues: Bool
    public internal(set) var navigationTarget: SBJEditorNavigationTarget?
    // The cached diagnostic list is the only source of truth for issue status.
    // nil means no diagnostic pass has completed for this editor session.
    private(set) var issues: [SBJEditorIssue]? = nil
    var hasIssues: Bool? { issues.map { !$0.isEmpty } }
    var issueResolutionRevision: UInt = 0
    var navigationRevision: UInt = 0

    public init(
        searchCriteria: SBJStructuralSearchCriteria = .init(),
        isShowingIssues: Bool = false,
        navigationTarget: SBJEditorNavigationTarget? = nil,
        formattingOptions: SBJEditorFormattingOptions = .init(),
        expansionOptions: SBJEditorExpansionOptions = .init()
    ) {
        self.searchCriteria = searchCriteria
        self.formattingOptions = formattingOptions
        self.expansionOptions = expansionOptions
        self.isShowingIssues = isShowingIssues
        self.navigationTarget = navigationTarget
    }

    /// Editor-wide actions are provided by the single injected presentation model,
    /// rather than propagated through nested custom environment keys.
    func showIssues() {
        isShowingIssues = true
    }

    func replaceIssues(_ newIssues: [SBJEditorIssue]) {
        issues = newIssues
    }

    /// A changed row-validation result invalidates the cached diagnostic pass.
    /// The search view recomputes the complete issue list; individual rows cannot
    /// determine whether another row still has issues.
    func reportValidationState(_ isInvalid: Bool) {
        issueResolutionRevision &+= 1
    }

    public func navigate(to target: SBJEditorNavigationTarget) {
        navigationTarget = target
        navigationRevision &+= 1
    }

    // Session-only choices override storage. Only explicit user choices are persisted.
    private var explicitChoices: [SBJEditorItemIdentifier: Bool] = [:]

    private func savedChoice(for id: SBJEditorItemIdentifier) -> Bool? {
        if let choice = explicitChoices[id] { return choice }
        guard let store = expansionOptions.store else { return nil }
        return store.expansion(for: id, namespace: expansionOptions.namespace)
    }

    func isUserExpanded(_ id: SBJEditorItemIdentifier, mode: SBJPresentationDisclosureMode) -> Bool {
        savedChoice(for: id) ?? (mode == .autoOpen || mode == .alwaysOpen)
    }

    func resolved(_ id: SBJEditorItemIdentifier, mode: SBJPresentationDisclosureMode,
                  search: Bool, navigation: Bool) -> Bool {
        mode == .alwaysOpen || isUserExpanded(id, mode: mode) || search || navigation
    }

    func setUserExpansion(_ expanded: Bool, for id: SBJEditorItemIdentifier, search: Bool) {
        guard !search else { return }
        explicitChoices[id] = expanded
        expansionOptions.store?.setExpansion(expanded, for: id, namespace: expansionOptions.namespace)
    }

    // Used when a user action creates content inside a collapsed disclosure.
    func open(_ id: SBJEditorItemIdentifier) {
        setUserExpansion(true, for: id, search: false)
    }

    /// Search and navigation only affect effective expansion; neither changes stored choices.
    /// The authoritative expansion decision for a presented row. Search and
    /// navigation may expose a branch without changing its saved user choice.
    func isExpanded(for context: SBJEditTraversalContext) -> Bool {
        resolved(
            context.itemIdentifier,
            mode: context.branch.disclosureMode,
            search: context.branch.searchCriteria.forcesExpansion(hasContent: context.branch.status.hasContent),
            navigation: navigationTarget?.contains(context.navigationPath) == true
        )
    }

    func navigationIncludes(_ context: SBJEditTraversalContext) -> Bool {
        navigationTarget?.contains(context.navigationPath) == true
    }

    func disclosureBinding(for context: SBJEditTraversalContext) -> Binding<Bool> {
        let identifier = context.itemIdentifier
        let mode = context.branch.disclosureMode
        let search = context.branch.searchCriteria.forcesExpansion(hasContent: context.branch.status.hasContent)
        let path = context.navigationPath
        return Binding(
            get: {
                self.resolved(identifier, mode: mode, search: search,
                              navigation: self.navigationTarget?.contains(path) == true)
            },
            set: { self.setUserExpansion($0, for: identifier, search: search) }
        )
    }
}

#endif
