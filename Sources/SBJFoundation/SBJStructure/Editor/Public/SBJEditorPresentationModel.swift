#if !os(tvOS) && !os(watchOS)
import SwiftUI
import Observation

/// Shared presentation state for one structured editor tree, independent of row lifetimes.
/// Owns root search/navigation/issue state and user disclosure preferences.
/// Child-specific search traversal is still derived locally and is not stored here.
@MainActor
@Observable
public final class SBJEditorPresentationModel {
    public var searchCriteria: SBJEditSearchCriteria
    public var formattingOptions: SBJEditorFormattingOptions

    public var isShowingIssues: Bool
    public internal(set) var navigationTarget: SBJEditorNavigationTarget?
    var hasIssues: Bool? = nil
    var issueResolutionRevision: UInt = 0
    var navigationRevision: UInt = 0

    public init(
        searchCriteria: SBJEditSearchCriteria = .init(),
        isShowingIssues: Bool = false,
        navigationTarget: SBJEditorNavigationTarget? = nil,
        formattingOptions: SBJEditorFormattingOptions = .init()
    ) {
        self.searchCriteria = searchCriteria
        self.formattingOptions = formattingOptions
        self.isShowingIssues = isShowingIssues
        self.navigationTarget = navigationTarget
    }

    public func navigate(to target: SBJEditorNavigationTarget) {
        navigationTarget = target
        navigationRevision &+= 1
    }

    private var explicitChoices: [SBJEditorItemIdentifier: Bool] = [:]

    func isUserExpanded(_ id: SBJEditorItemIdentifier, mode: SBJEditorDisclosureMode) -> Bool {
        explicitChoices[id] ?? (mode == .autoOpen || mode == .alwaysOpen)
    }

    func resolved(_ id: SBJEditorItemIdentifier, mode: SBJEditorDisclosureMode,
                  search: Bool, navigation: Bool) -> Bool {
        mode == .alwaysOpen || isUserExpanded(id, mode: mode) || search || navigation
    }

    func setUserExpansion(_ expanded: Bool, for id: SBJEditorItemIdentifier, search: Bool) {
        guard !search else { return }
        explicitChoices[id] = expanded
    }

    func open(_ id: SBJEditorItemIdentifier) {
        explicitChoices[id] = true
    }

    func commitNavigationExpansion(target: SBJEditorNavigationTarget?, path: [String],
                                   id: SBJEditorItemIdentifier) {
        guard target?.isDescendant(of: path) == true else { return }
        open(id)
    }
}

#endif
