import Testing
@testable import SBJStructure

@SBJStructure
struct TraversalOptionsFixture {
    public let identifier: Int
    var content: String
    private let hidden: Int
    fileprivate var hiddenVariable: Int
    @SBJExcludeFromStructuralEquivalence
    private var cache: Int
    @SBJExcludeFromStructuralEquivalence
    var transient: Int
    var computed: Int { content.count }

    init(identifier: Int = 1, content: String = "x", hidden: Int = 2,
         hiddenVariable: Int = 3, cache: Int = 4, transient: Int = 5) {
        self.identifier = identifier
        self.content = content
        self.hidden = hidden
        self.hiddenVariable = hiddenVariable
        self.cache = cache
        self.transient = transient
    }
}

struct SBJTraversalOptionsTests {
    @Test func comparisonIncludesAllStoredInstanceStateExceptExplicitExclusions() {
        let value = TraversalOptionsFixture()
        #expect(value.sbjStructuralEquals(.init(cache: 99, transient: 99)))
        #expect(!value.sbjStructuralEquals(.init(identifier: 99)))
        #expect(!value.sbjStructuralEquals(.init(hidden: 99)))
        #expect(!value.sbjStructuralEquals(.init(hiddenVariable: 99)))
        #expect(!value.sbjStructuralEquals(.init(content: "y")))
        #expect(TraversalOptionsFixture.sbjProperties.contains { $0.sourceName == "transient" })
    }

    @Test func traversalFiltersPreserveDeclarationOrdinals() {
        let complete = SBJStructuralTraversal.definition(of: TraversalOptionsFixture.self)
        #expect(complete.map(\.sourceName) == ["identifier", "content", "transient", "computed"])
        let storedWritable = SBJTraversalOptions.editor.subtracting(.computed)
        let filtered = SBJStructuralTraversal.definition(of: TraversalOptionsFixture.self, options: storedWritable)
        #expect(filtered.map(\.sourceName) == ["content", "transient"])
        #expect(filtered.map(\.ordinal) == [1, 2])
        let publicOnly = SBJTraversalOptions.all.subtracting([.internalAccess, .packageAccess])
        #expect(SBJStructuralTraversal.definition(of: TraversalOptionsFixture.self, options: publicOnly).map(\.sourceName) == ["identifier"])
        #expect(SBJStructuralTraversal.descendants(in: TraversalOptionsFixture(), options: storedWritable).map(\.locationPath) == [["field:1"], ["field:2"]])
    }
}
