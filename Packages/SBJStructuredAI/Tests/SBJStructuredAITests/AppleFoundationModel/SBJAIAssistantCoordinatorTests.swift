#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Testing
@testable import SBJStructuredAI

@Suite("Conversation-only coordinator")
@MainActor
struct SBJAIAssistantCoordinatorTests {
    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test("Initial and reset lifecycle requires no inference")
    func initialSessionStateRequiresNoInference() {
        let coordinator = SBJAIAssistantCoordinator<Int>(snapshot: { nil })
        #expect(!coordinator.isActive)
        #expect(!coordinator.isResponding)
        #expect(coordinator.frameworkTranscript == nil)
        #expect(coordinator.messages.isEmpty)
        coordinator.activate()
        #expect(coordinator.isActive)
        coordinator.stop()
        #expect(coordinator.messages.isEmpty)
        coordinator.deactivate()
        #expect(!coordinator.isActive)
        coordinator.activate()
        #expect(coordinator.frameworkTranscript == nil)
        #expect(coordinator.messages.isEmpty)
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test("An arbitrary root needs no structural conformance and cannot be persisted")
    func inertMutationAPI() {
        struct Root { let name: String }
        var persistCalls = 0
        let coordinator = SBJAIAssistantCoordinator<Root>(snapshot: {
            .init(id: "test", revision: 1, model: .init(name: "Test"), allowsEditing: true)
        }, persist: { _, _, _, _ in persistCalls += 1 })
        coordinator.activate()
        coordinator.approve()
        coordinator.reject()
        coordinator.restore()
        coordinator.synchronize()
        #expect(coordinator.pendingProposal == nil)
        #expect(!coordinator.canApprove)
        #expect(!coordinator.canRestore)
        #expect(!coordinator.isPersisting)
        #expect(persistCalls == 0)
        #expect(coordinator.hasDocument)
        #expect(coordinator.messages.isEmpty)
        coordinator.deactivate()
        coordinator.submit("Hello")
        #expect(!coordinator.isResponding)
        #expect(coordinator.messages.isEmpty)
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test("Prewarm does not activate the coordinator or create messages")
    func prewarmIsConversationNeutral() {
        let coordinator = SBJAIAssistantCoordinator<Int>(snapshot: { nil })
        // No real inference, and no model loading in routine unit tests when ready.
        guard SBJAIAvailability.state != .ready else { return }
        coordinator.prewarm()
        coordinator.prewarm()
        #expect(!coordinator.isActive)
        #expect(!coordinator.isResponding)
        #expect(coordinator.messages.isEmpty)
        coordinator.deactivate()
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test("An empty draft or missing document cannot start a turn")
    func submissionGuards() {
        let coordinator = SBJAIAssistantCoordinator<Int>(snapshot: { nil }, persist: { _, _, _, _ in })
        coordinator.activate()
        coordinator.submit("   ")
        coordinator.submit("Hello")
        #expect(!coordinator.isResponding)
        #expect(coordinator.messages.isEmpty)
    }
}
#endif
