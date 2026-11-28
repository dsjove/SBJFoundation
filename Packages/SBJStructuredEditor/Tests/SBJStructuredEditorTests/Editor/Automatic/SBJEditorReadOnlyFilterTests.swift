#if !os(tvOS) && !os(watchOS)
import SwiftUI
import Testing
import SBJStructure
@testable import SBJStructuredEditor

@SBJStructure
private struct ReadOnlyFilterChild {
    var value: String = "writable-token"
    let identifier: String = "immutable-token"
    var derived: String { "derived-token" }
    var editableComputed: String {
        get { value }
        set { value = newValue }
    }
    @SBJFieldPresentation(exclude: true)
    var excluded: String = "excluded-token"
}

@SBJStructure
private enum ReadOnlyFilterChoice {
    case automatic
    case child(ReadOnlyFilterChild)
}

@SBJStructure
private struct ReadOnlyFilterRoot {
    var child: ReadOnlyFilterChild = .init()
    var optionalChild: ReadOnlyFilterChild? = .init()
    var children: [ReadOnlyFilterChild] = [.init()]
    var namedChildren: [String: ReadOnlyFilterChild] = ["Entry": .init()]
    var choice: ReadOnlyFilterChoice = .child(.init())
}

@MainActor
struct SBJEditorReadOnlyFilterTests {
    @Test func defaultsToWritableFieldsAndPreservesSemanticDefinition() {
        #expect(!SBJTraversalOptions.editor.contains(.readOnly))
        #expect(SBJTraversalOptions.all.contains(.readOnly))
        let writable = SBJStructuralFieldProjection.fields(of: ReadOnlyFilterChild.self)
        let all = SBJStructuralFieldProjection.fields(of: ReadOnlyFilterChild.self, traversalOptions: .all)
        #expect(writable.map { $0.metadata.sourceName } == ["value", "editableComputed"])
        #expect(all.map { $0.metadata.sourceName } == ["value", "identifier", "derived", "editableComputed"])
        #expect(all.filter { $0.metadata.access == .readOnly }.count == 2)
        #expect(ReadOnlyFilterChild.sbjProperties.filter { !$0.isPresentationExcluded }.map(\.sourceName) == all.map { $0.metadata.sourceName })
        #expect(ReadOnlyFilterChild.sbjProperties.contains { $0.sourceName == "excluded" })
        #expect(ReadOnlyFilterChild._sbjStructuralFieldCount() == 2)
        #expect(ReadOnlyFilterChild._sbjStructuralFieldCount(traversalOptions: .all) == 4)
    }

    @Test func filterAppliesToBoundAndUnboundNestedTraversal() throws {
        let root = ReadOnlyFilterRoot()
        for showsReadOnly in [false, true] {
            let context = SBJEditTraversalContext.root.withBranch(.init(traversalOptions: showsReadOnly ? .all : .editor))
            let snapshot = ReadOnlyFilterRoot._sbjStructuralTraversalNodes(value: root, context: context)
            let bound = ReadOnlyFilterRoot._sbjStructuralBoundNodes(
                binding: SBJAnyBinding(Binding.constant(root)), originalValue: root,
                registry: .init(), context: context
            )
            let expected = showsReadOnly ? ["Value", "Identifier", "Derived", "Editable Computed"] : ["Value", "Editable Computed"]
            for nodes in [snapshot, bound] {
                for name in ["Child", "Optional Child"] {
                    let node = try #require(nodes.first { $0.name == name })
                    #expect(node.children().map(\.name) == expected)
                }
                for name in ["Children", "Named Children", "Choice"] {
                    let node = try #require(nodes.first { $0.name == name })
                    let item = try #require(node.children().first)
                    #expect(item.children().map(\.name) == expected)
                    #expect(item.context.branch.traversalOptions == (showsReadOnly ? .all : .editor))
                }
            }
        }
    }

    @Test func togglingDoesNotChangeWritableIdentityOrLocation() {
        let root = ReadOnlyFilterChild()
        let hidden = ReadOnlyFilterChild._sbjStructuralTraversalNodes(value: root, context: .root)
        let shown = ReadOnlyFilterChild._sbjStructuralTraversalNodes(
            value: root, context: .root.withBranch(.init(traversalOptions: .all))
        )
        for row in hidden {
            let matching = shown.first { $0.name == row.name }
            #expect(matching?.id == row.id)
            #expect(matching?.context.indexPath == row.context.indexPath)
        }
    }

    @Test func textSearchDoesNotRevealHiddenPropertiesOrTheirAncestors() {
        let root = ReadOnlyFilterRoot()
        let presentation = SBJEditorPresentationModel(searchCriteria: .init(searchQuery: "derived-token"))
        for showsReadOnly in [false, true] {
            let context = SBJEditTraversalContext.root.withBranch(.init(traversalOptions: showsReadOnly ? .all : .editor))
            let bound = ReadOnlyFilterRoot._sbjStructuralBoundNodes(
                binding: SBJAnyBinding(Binding.constant(root)), originalValue: root,
                registry: .init(), context: context
            )
            let rows = sbjEditorRows(roots: bound, presentationModel: presentation)
            if showsReadOnly {
                #expect(rows.contains { $0.name == "Derived" })
            } else {
                #expect(rows.isEmpty)
            }
        }
    }
}
#endif
