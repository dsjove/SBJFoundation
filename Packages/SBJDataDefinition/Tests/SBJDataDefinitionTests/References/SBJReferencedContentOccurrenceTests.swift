import Testing
@testable import SBJDataDefinition

@Suite("Referenced content occurrences")
struct SBJReferencedContentOccurrenceTests {
    @Test("Referenced content occurrence retains source path")
    func contentOccurrence() {
        let id = SBJReferencedContentID("portrait")
        #expect(SBJReferencedContentOccurrence(id: id, path: "portrait").id == id)
    }
}
