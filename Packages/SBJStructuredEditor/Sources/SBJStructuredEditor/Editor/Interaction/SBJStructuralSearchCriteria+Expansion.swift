import SBJDataDefinition

/// Presentation-only policy: active structural filtering may reveal collapsed descendants.
/// Kept out of DataDefinition because it describes editor disclosure, not model matching.
extension SBJStructuralSearchCriteria {
    func forcesExpansion(hasContent: Bool?) -> Bool {
        !searchQuery.isEmpty || showChangedOnly || (showEmptyContentOnly && hasContent != false)
    }
}
