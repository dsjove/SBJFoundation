#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Foundation
import FoundationModels
import Testing
@testable import SBJStructuredAI

@Suite("Native leaf mutation tool")
struct SBJAIMutateValueToolTests {
    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func returnsActualOutcomeAndPreservesNegotiation() async throws {
        let applied = SBJAIMutateValueTool { path, value in
            #expect(path == ["2", "@1", "3"])
            #expect(value == "12")
            return SBJAIInstructions.mutationApplied
        }
        #expect(applied.name == "mutateValue")
        #expect(try await applied.call(arguments: .init(keyPath: ["2", "@1", "3"], value: "12")) == "status:applied")
        let rejected = SBJAIMutateValueTool { _, _ in SBJAIInstructions.mutationRejected }
        #expect(try await rejected.call(arguments: .init(keyPath: ["2"], value: "12")) == "status:rejected")
        let invalid = SBJAIMutateValueTool { _, _ in throw SBJLeafMutationError.resolution("memberRequired:replace:2;keys:@1,@2") }
        #expect(try await invalid.call(arguments: .init(keyPath: ["2", "bad"], value: "12")) == "memberRequired:replace:2;keys:@1,@2")
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func staleSnapshotDoesNotReturnValues() async throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJTransactionFixture())
        let field = String(try #require(snapshot.declarationIdentifier(for: [.field("level")])))
        let tool = SBJAIReadValueTool(snapshot: snapshot, isCurrent: { false })
        #expect(try await tool.call(arguments: .init(keyPath: [field])) == SBJSemanticReadResult.error(SBJAIInstructions.staleToolResult).promptText)
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test @MainActor func reviewWaitsForHostPersistence() async throws {
        var document: SBJAssistantDocument<SBJTransactionFixture>?
        var finish: (@MainActor (Result<Void, Error>) -> Void)?
        var candidate: SBJTransactionFixture?
        let coordinator = SBJAIAssistantCoordinator(snapshot: { document }, persist: { model, _, _, completion in
            candidate = model
            finish = completion
        }, domainInstructions: "Test document.")
        coordinator.activate() // No document at activation; no native inference needed.
        let original = SBJAssistantDocument(id: "doc", revision: 1, model: SBJTransactionFixture(), allowsEditing: true)
        document = original
        let context = try SBJSemanticReadSnapshot(instance: original.model)
        let field = String(try #require(context.declarationIdentifier(for: [.field("level")])))
        let call = Task { @MainActor in
            try await coordinator.requestLeafMutation(document: original, context: context, path: [field], value: "12")
        }
        defer { call.cancel(); coordinator.deactivate() }
        for _ in 0..<100 where coordinator.pendingProposal == nil { await Task.yield() }
        try #require(coordinator.pendingProposal != nil)
        #expect(candidate == nil)
        #expect(coordinator.canApprove)
        coordinator.approve()
        #expect(coordinator.isPersisting)
        #expect(candidate?.level == 12)
        #expect(document?.model.level == 9)
        document = .init(id: "doc", revision: 2, model: try #require(candidate), allowsEditing: true)
        let completion = try #require(finish)
        completion(.success(()))
        #expect(try await call.value == "status:applied")
        #expect(!coordinator.isPersisting)
        #expect(document?.model.level == 12)
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test @MainActor func rejectionAndCancellationDoNotPersist() async throws {
        var document: SBJAssistantDocument<SBJTransactionFixture>?
        var persistCalls = 0
        let coordinator = SBJAIAssistantCoordinator(snapshot: { document }, persist: { _, _, _, _ in persistCalls += 1 }, domainInstructions: "Test document.")
        coordinator.activate()
        let original = SBJAssistantDocument(id: "doc", revision: 1, model: SBJTransactionFixture(), allowsEditing: true)
        document = original
        let context = try SBJSemanticReadSnapshot(instance: original.model)
        let field = String(try #require(context.declarationIdentifier(for: [.field("level")])))
        let call = Task { @MainActor in
            try await coordinator.requestLeafMutation(document: original, context: context, path: [field], value: "12")
        }
        defer { call.cancel(); coordinator.deactivate() }
        for _ in 0..<100 where coordinator.pendingProposal == nil { await Task.yield() }
        try #require(coordinator.pendingProposal != nil)
        coordinator.reject()
        #expect(try await call.value == "status:rejected")
        #expect(persistCalls == 0)
        coordinator.deactivate()
        document = nil
        coordinator.activate()
        document = original
        let second = Task { @MainActor in
            try await coordinator.requestLeafMutation(document: original, context: context, path: [field], value: "13")
        }
        defer { second.cancel() }
        for _ in 0..<100 where coordinator.pendingProposal == nil { await Task.yield() }
        try #require(coordinator.pendingProposal != nil)
        coordinator.stop()
        do { _ = try await second.value; Issue.record("Expected cancellation") }
        catch is CancellationError {}
        #expect(coordinator.pendingProposal == nil)
        #expect(persistCalls == 0)
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test @MainActor func resetCancelsPendingMutationWithoutPersistence() async throws {
        var document: SBJAssistantDocument<SBJTransactionFixture>?
        var persistCalls = 0
        let coordinator = SBJAIAssistantCoordinator(snapshot: { document }, persist: { _, _, _, _ in persistCalls += 1 }, domainInstructions: "Test document.")
        coordinator.activate()
        let original = SBJAssistantDocument(id: "doc", revision: 1, model: SBJTransactionFixture(), allowsEditing: true)
        document = original
        let context = try SBJSemanticReadSnapshot(instance: original.model)
        let field = String(try #require(context.declarationIdentifier(for: [.field("level")])))
        let previousTurn = coordinator.currentTurnID
        let call = Task { @MainActor in
            try await coordinator.requestLeafMutation(document: original, context: context, path: [field], value: "12")
        }
        defer { call.cancel(); coordinator.deactivate() }
        for _ in 0..<100 where coordinator.pendingProposal == nil { await Task.yield() }
        try #require(coordinator.pendingProposal != nil)
        coordinator.startNewSession()
        do { _ = try await call.value; Issue.record("Expected cancellation") }
        catch is CancellationError {}
        #expect(coordinator.pendingProposal == nil)
        #expect(!coordinator.isResponding)
        #expect(coordinator.isActive)
        #expect(coordinator.currentTurnID != previousTurn)
        #expect(coordinator.messages.isEmpty)
        #expect(document?.model.level == 9)
        #expect(persistCalls == 0)
    }

}
#endif
