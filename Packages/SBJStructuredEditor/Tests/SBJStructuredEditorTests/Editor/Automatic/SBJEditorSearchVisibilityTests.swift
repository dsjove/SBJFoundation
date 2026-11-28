#if !os(tvOS) && !os(watchOS)
import Testing
import SBJStructure
@testable import SBJStructuredEditor

@SBJStructure
private struct SearchVisibilityFixture {
    var visible: String = "writable-token"
    let immutable: String = "immutable-token"
    var derived: String { "derived-token" }
    @SBJFieldPresentation(exclude: true)
    var excluded: String = "excluded-token"
}

@SBJStructure
private enum SearchVisibilityChoice {
    case automatic
    case wrapped(SearchVisibilityFixture)
}

struct SBJEditorSearchVisibilityTests {
    @Test func recursiveTextSearchHonorsReadOnlyFilter() {
        let fixture = SearchVisibilityFixture()
        let values: [Any] = [fixture, Optional.some(fixture) as Any, [fixture],
                             ["entry": fixture], SearchVisibilityChoice.wrapped(fixture)]
        for value in values {
            for query in ["immutable-token", "derived-token", "Derived"] {
                #expect(!SBJEditorSearchMatcher.matches(label: "Container", value: value, query: query, traversalOptions: .editor))
                #expect(SBJEditorSearchMatcher.matches(label: "Container", value: value, query: query, traversalOptions: .all))
            }
            for showsReadOnly in [false, true] {
                #expect(SBJEditorSearchMatcher.matches(label: "Container", value: value, query: "writable-token", traversalOptions: showsReadOnly ? .all : .editor))
                #expect(!SBJEditorSearchMatcher.matches(label: "Container", value: value, query: "excluded-token", traversalOptions: showsReadOnly ? .all : .editor))
            }
        }
    }
}
#endif
