import SBJStructure
import SwiftUI
import Testing
@testable import SBJStructuredEditor

#if !os(tvOS) && !os(watchOS)
@SBJStructure(atomic: true)
private struct AtomicEditorFixture: SBJTextPresentable {
    @SBJInteger(range: 0...100)
    var amount = 3
    @SBJExclude var presentedValue: String { "\(amount) points" }
}

@MainActor
@Suite struct SBJAtomicValueProjectionTests {
    @Test func atomicRowsHaveNoAutomaticDescendants() {
        let value = AtomicEditorFixture()
        let node = SBJEditorValueTraversal.node(named: "Amount", value: value, context: .root)
        #expect(!node.isDisclosure)
        #expect(node.children().isEmpty)
        let bound = SBJEditorValueTraversal.boundNode(named: "Amount", binding: .constant(value), context: .root, registry: .init())
        #expect(!bound.isDisclosure)
        #expect(bound.children().isEmpty)
        #expect(bound.renderedRow() != nil)
    }

    @Test func optionalAtomicValuesKeepTheLeafBoundary() {
        let absent: AtomicEditorFixture? = nil
        let present: AtomicEditorFixture? = .init()
        for value in [absent, present] {
            let node = SBJEditorValueTraversal.boundNode(named: "Optional", binding: .constant(value), context: .root, registry: .init())
            #expect(!node.isDisclosure)
            #expect(node.children().isEmpty)
        }
        #expect(!SBJEditorValueTraversal.isLeaf([AtomicEditorFixture].self))
    }

    @Test func canonicalMemberEditorsRemainAvailable() {
        let value = AtomicEditorFixture()
        let children = AtomicEditorFixture._sbjStructuralBoundNodes(
            binding: SBJAnyBinding(Binding.constant(value)), originalValue: nil,
            registry: .init(), context: .root)
        #expect(children.count == 1)
        #expect(children.first?.renderedRow() != nil)
        let fields = SBJStructuralTraversal.definition(of: AtomicEditorFixture.self)
        #expect(fields.first(where: { $0.sourceName == "amount" })?.constraints.isEmpty == false)
    }
}
#endif
