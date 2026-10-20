import Testing
@testable import SBJStructuredEditor
import SBJUIVocabulary
import SBJUnits

@Suite("SBJ edit traversal context")
struct SBJEditTraversalContextTests {
    @Test("root begins at tree level zero")
    func rootLevel() {
        #expect(SBJEditTraversalContext.root.treeLevel == 0)
    }

    @Test("descending increments tree level without mutating parent")
    func descendedLevel() {
        let parent = SBJEditTraversalContext(treeLevel: 2)
        let child = parent.descended()

        #expect(parent.treeLevel == 2)
        #expect(child.treeLevel == 3)
    }
}

@Suite("SBJ editor snapshot identity")
struct SBJEditorSnapshotIdentityTests {
    @Test("collection item identity is independent from its current index path")
    func collectionItemIdentityVsIndexPath() {
        let parent = SBJEditTraversalContext.root.property("relationships")
        let first = parent.descended(stableIdentifier: "relationship-42", index: 0)
        let moved = parent.descended(stableIdentifier: "relationship-42", index: 3)

        #expect(first.itemIdentifier == moved.itemIdentifier)
        #expect(first.indexPath != moved.indexPath)
    }

    @Test("different parent properties keep identical slots distinct")
    func parentPropertyDisambiguatesSlots() {
        let traits = SBJEditTraversalContext.root
            .property("traits")
            .descended(stableIdentifier: "slot:0", index: 0)
        let ideals = SBJEditTraversalContext.root
            .property("ideals")
            .descended(stableIdentifier: "slot:0", index: 0)

        #expect(traits.itemIdentifier != ideals.itemIdentifier)
    }
}

@Suite("Explicit editor branch context")
struct SBJEditorBranchContextTests {
    @Test("child retains search while resetting row status and placement")
    func childResetsTransientRowState() {
        let criteria = SBJEditSearchCriteria(searchQuery: "backstory", showChangedOnly: true)
        let branch = SBJEditorBranchContext(searchCriteria: criteria)
            .withStatus(.init(isChanged: true, hasContent: false, isInvalid: true))
            .withPlacement(.embedded)
            .withDisclosureMode(.alwaysOpen)
        let parent = SBJEditTraversalContext.root.withBranch(branch)
        let child = parent.descended(property: "name")

        #expect(parent.branch.status.isChanged)
        #expect(child.branch.searchCriteria == criteria)
        #expect(child.branch.status == .init())
        #expect(child.branch.placement == .normal)
        #expect(child.branch.disclosureMode == .closed)
        #expect(parent.branch.disclosureMode == .alwaysOpen)
    }

    @Test("branch mutators do not mutate the source")
    func valueCopySemantics() {
        let source = SBJEditorBranchContext()
        let updated = source.withSearchCriteria(.init(searchQuery: "test"))
            .withPropertyInfoPlacement(.hidden)
            .withStatus(.init(isChanged: true))
        #expect(source.searchCriteria.searchQuery.isEmpty)
        #expect(source.propertyInfoPlacement == .overlay)
        #expect(!source.status.isChanged)
        #expect(updated.searchCriteria.searchQuery == "test")
        #expect(updated.propertyInfoPlacement == .hidden)
        #expect(updated.status.isChanged)
    }
}
