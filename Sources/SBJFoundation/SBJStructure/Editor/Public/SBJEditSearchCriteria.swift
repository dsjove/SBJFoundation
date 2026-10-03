import Foundation

/// UI-independent search and filter criteria for structured editing.
///
/// Keeping the criteria together lets editors add new filters without threading
/// additional independent flags through every recursive editor view.
public struct SBJEditSearchCriteria: Equatable, Sendable {
    public var searchQuery: String
    public var showChangedOnly: Bool
    public var showEmptyContentOnly: Bool

    public init(
        searchQuery: String = "",
        showChangedOnly: Bool = false,
        showEmptyContentOnly: Bool = false
    ) {
        self.searchQuery = searchQuery
        self.showChangedOnly = showChangedOnly
        self.showEmptyContentOnly = showEmptyContentOnly
    }

    /// Whether no search or filter criteria are currently enabled.
    public var isEmpty: Bool {
        searchQuery.isEmpty && !showChangedOnly && !showEmptyContentOnly
    }

    public func forcesExpansion(hasContent: Bool?) -> Bool {
        !searchQuery.isEmpty || showChangedOnly || (showEmptyContentOnly && hasContent != false)
    }

    /// Returns criteria appropriate for descendants when an ancestor label has
    /// already satisfied the text query. Non-text filters remain active.
    public func descendingPastMatchedLabel(_ label: String) -> Self {
        guard !searchQuery.isEmpty, sbjPredicated(label, search: searchQuery) else {
            return self
        }
        var copy = self
        copy.searchQuery = ""
        return copy
    }

    /// Returns criteria appropriate for descendants when any label on the
    /// current traversal edge has already satisfied the text query. This is
    /// useful for compound nodes such as collection entries and enum cases,
    /// which can expose more than one visible label before descending.
    public func descendingPastMatchedLabels(_ labels: String...) -> Self {
        guard !searchQuery.isEmpty, labels.contains(where: { sbjPredicated($0, search: searchQuery) }) else {
            return self
        }
        var copy = self
        copy.searchQuery = ""
        return copy
    }

    /// Applies all active criteria in one pass. Expensive predicates are lazy
    /// and are only evaluated if their corresponding criterion is enabled.
    public func includes(
        isChanged: @autoclosure () -> Bool,
        containsEmptyContent: @autoclosure () -> Bool,
        matchesSearch: (String) -> Bool
    ) -> Bool {
        if showChangedOnly && !isChanged() { return false }
        if showEmptyContentOnly && !containsEmptyContent() { return false }
        if !searchQuery.isEmpty && !matchesSearch(searchQuery) { return false }
        return true
    }
}
