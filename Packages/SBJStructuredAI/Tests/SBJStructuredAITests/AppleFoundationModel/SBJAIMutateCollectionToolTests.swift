#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Foundation
import FoundationModels
import Testing
@testable import SBJStructuredAI

@Suite("Native collection mutation tool")
struct SBJAIMutateCollectionToolTests {
    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func returnsCountAndActualReviewOutcome() async throws {
        let tool = SBJAIMutateCollectionTool { request in
            #expect(request.keyPath == ["2"])
            if request.operation == "count" { return "value:2" }
            #expect(request.member == "@1")
            #expect(request.position == 2)
            #expect(request.value == nil)
            return SBJAIInstructions.mutationApplied
        }
        #expect(tool.name == "mutateCollection")
        #expect(try await tool.call(arguments: .init(keyPath: ["2"], operation: "count", member: nil, position: nil, value: nil)) == "value:2")
        #expect(try await tool.call(arguments: .init(keyPath: ["2"], operation: "move", member: "@1", position: 2, value: nil)) == "status:applied")
        let rejected = SBJAIMutateCollectionTool { _ in SBJAIInstructions.mutationRejected }
        #expect(try await rejected.call(arguments: .init(keyPath: ["2"], operation: "clear", member: nil, position: nil, value: nil)) == "status:rejected")
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test @MainActor func countDoesNotStageAndCollectionReviewUsesSharedWaiter() async throws {
        var document: SBJAssistantDocument<SBJSemanticReadFixture>?
        var persistCalls = 0
        let coordinator = SBJAIAssistantCoordinator(snapshot: { document }, persist: { _, _, _, _ in persistCalls += 1 }, domainInstructions: "Test document.")
        coordinator.activate()
        let original = SBJAssistantDocument(id: "doc", revision: 1, model: SBJSemanticReadFixture(), allowsEditing: true)
        document = original
        let context = try SBJSemanticReadSnapshot(instance: original.model)
        let field = String(try #require(context.declarationIdentifier(for: [.field("items")])))
        #expect(try await coordinator.requestCollectionMutation(document: original, context: context, request: .init(keyPath: [field], operation: "count")) == "value:2")
        #expect(coordinator.pendingProposal == nil)
        let call = Task { @MainActor in
            try await coordinator.requestCollectionMutation(document: original, context: context, request: .init(keyPath: [field], operation: "remove", member: "@1"))
        }
        defer { call.cancel(); coordinator.deactivate() }
        for _ in 0..<100 where coordinator.pendingProposal == nil { await Task.yield() }
        try #require(coordinator.pendingProposal != nil)
        #expect(persistCalls == 0)
        coordinator.reject()
        #expect(try await call.value == "status:rejected")
        #expect(persistCalls == 0)
    }
}
#endif
