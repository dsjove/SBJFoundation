#if !os(tvOS) && !os(watchOS)
import SwiftUI
import Testing
@testable import SBJFoundation

@MainActor
@Suite("Flat projection descriptor audit")
struct SBJFlatProjectionAuditTests {
    private func node(
        _ name: String,
        id: String,
        path: [String],
        scope: SBJEditorTraversalNode.RenderingScope = .recursive,
        canRender: Bool = true
    ) -> SBJEditorTraversalNode {
        SBJEditorTraversalNode(
            context: SBJEditTraversalContext(
                treeLevel: path.count,
                itemIdentifier: .root.appending(id),
                navigationPath: path
            ),
            name: name,
            render: canRender ? { AnyView(EmptyView()) } : nil,
            renderingScope: scope
        )
    }

    @Test("duplicate logical identities are reported")
    func duplicateIDs() {
        let result = sbjAuditFlatRows([
            node("first", id: "reused", path: ["first"]),
            node("second", id: "reused", path: ["second"])
        ])
        #expect(result.duplicateIdentifiers.count == 1)
        #expect(!result.canUseIndependentFlatRenderer)
    }

    @Test("recursive parents with separately projected descendants are unsafe")
    func recursiveParent() {
        let result = sbjAuditFlatRows([
            node("parent", id: "parent", path: ["parent"]),
            node("child", id: "child", path: ["parent", "child"])
        ])
        #expect(result.recursivelyRenderedParents.count == 1)
        #expect(!result.canUseIndependentFlatRenderer)
    }

    @Test("atomic rows and independently rendered children are compatible")
    func atomicRows() {
        let result = sbjAuditFlatRows([
            node("parent", id: "parent", path: ["parent"], scope: .atomic),
            node("child", id: "child", path: ["parent", "child"], scope: .atomic)
        ])
        #expect(result.canUseIndependentFlatRenderer)
    }

    @Test("snapshot-only descriptors are identified")
    func missingFactory() {
        let result = sbjAuditFlatRows([
            node("snapshot", id: "snapshot", path: ["snapshot"], canRender: false)
        ])
        #expect(result.nonRenderableIdentifiers.count == 1)
    }
}
#endif
