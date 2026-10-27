import SBJDataDefinition
import Testing
@testable import SBJStructuredEditor

@Suite("Structural search editor expansion")
struct SBJStructuralSearchExpansionTests {
    @Test("inactive filtering does not expand")
    func noFilter() {
        #expect(!SBJStructuralSearchCriteria().forcesExpansion(hasContent: nil))
    }

    @Test("text and change filters expand independently of content")
    func textAndChanged() {
        #expect(SBJStructuralSearchCriteria(searchQuery: "needle").forcesExpansion(hasContent: false))
        #expect(SBJStructuralSearchCriteria(showChangedOnly: true).forcesExpansion(hasContent: false))
    }

    @Test("empty-content filtering expands only when not known to have content absent")
    func emptyContent() {
        let criteria = SBJStructuralSearchCriteria(showEmptyContentOnly: true)
        #expect(criteria.forcesExpansion(hasContent: nil))
        #expect(criteria.forcesExpansion(hasContent: true))
        #expect(!criteria.forcesExpansion(hasContent: false))
    }
}
