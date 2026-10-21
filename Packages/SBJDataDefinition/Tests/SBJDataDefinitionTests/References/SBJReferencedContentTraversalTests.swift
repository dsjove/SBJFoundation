import Testing
@testable import SBJDataDefinition

@SBJStructure
private struct ResourceLeaf: Codable, Equatable {
    var resource: SBJReferencedContentID?
}

@SBJStructure
private struct ResourceRoot: Codable, Equatable {
    var direct: SBJReferencedContentID?
    var children: [ResourceLeaf]
}

@Suite("SBJ resource discovery")
struct SBJReferencedContentTraversalTests {
    @Test("Discovers resource IDs across structured values and collections with paths")
    func discovery() {
        let root = ResourceRoot(
            direct: .init("direct"),
            children: [.init(resource: .init("nested")), .init(resource: nil)]
        )
        let usages = Set(root.sbjReferencedContentOccurrences())
        #expect(usages.contains(.init(id: .init("direct"), path: "direct")))
        #expect(usages.contains(.init(id: .init("nested"), path: "children[0].resource")))
    }
}
