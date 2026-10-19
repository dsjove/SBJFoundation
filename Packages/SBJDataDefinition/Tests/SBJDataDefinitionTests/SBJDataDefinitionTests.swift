import Foundation
import Testing
@testable import SBJDataDefinition

@Test func structuralSearchMatchesText() {
    #expect(sbjPredicated("hello world", search: "HELLO"))
    #expect(!sbjPredicated("hello world", search: "goodbye"))
}

@Test func structuralCollectionIdentityUsesIndexFallback() {
    #expect(SBJCollectionItemIdentification.arrayTitle(for: "value", index: 2) == "[2]")
}

@Test func referencedContentIdentityRoundTrips() throws {
    let id = SBJReferencedContentID("example")
    let decoded = try JSONDecoder().decode(SBJReferencedContentID.self, from: JSONEncoder().encode(id))
    #expect(decoded == id)
}
