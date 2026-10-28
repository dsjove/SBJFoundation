import Testing
@testable import SBJDataDefinition

@Suite("Atomic structural search")
struct SBJStructuralSearchAtomicTests {
    private struct PrivateDetail: SBJStructuralSearchAtomic, CustomStringConvertible {
        let hidden: String
        var description: String { "public summary" }
    }

    @Test("atomic values match their description but not reflected members")
    func stopsReflection() {
        let value = PrivateDetail(hidden: "secret token")
        #expect(sbjPredicated(value, search: "public summary"))
        #expect(!sbjPredicated(value, search: "secret token"))
    }

}
