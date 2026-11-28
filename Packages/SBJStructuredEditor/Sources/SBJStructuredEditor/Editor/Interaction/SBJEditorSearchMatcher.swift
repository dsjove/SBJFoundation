import SBJStructure
#if !os(tvOS) && !os(watchOS)
/// Apply the editor's structural visibility policy to the shared search implementation.
enum SBJEditorSearchMatcher {
    static func matches(
        label: String, value: Any, query: String, traversalOptions: SBJTraversalOptions
    ) -> Bool {
        sbjPredicated(label: label, value: value, search: query,
                      traversalOptions: traversalOptions)
    }
}
#endif
