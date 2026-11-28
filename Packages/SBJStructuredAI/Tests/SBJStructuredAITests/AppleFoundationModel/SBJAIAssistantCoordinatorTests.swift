#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import FoundationModels
import Testing
@testable import SBJStructuredAI

@Suite("Conversation-only coordinator")
@MainActor
struct SBJAIAssistantCoordinatorTests {
    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func printInstructionsWithoutNativeSession() throws {
        let coordinator = SBJAIAssistantCoordinator<Int>(snapshot: {
            .init(id: "test", revision: 1, model: 42, allowsEditing: false)
        }, domainInstructions: "Test document.")
        let context = try SBJSemanticReadSnapshot(instance: 42)
        coordinator.feedback.isEnabled = true
        #expect(coordinator.canPrintInstructions)
        coordinator.printInstructions()
        #expect(coordinator.messages.count == 1)
        #expect(coordinator.messages.last?.speaker == .diagnostic)
        let expected = coordinator.instructions + "\n\n" + SBJAIInstructions.structureHeading + context.structuralDescription(usesTemplates: true)
        #expect(coordinator.messages.last?.text == expected)
        #expect(coordinator.exportText.contains(expected))
        #expect(coordinator.sessionInstructions == nil)
        #expect(coordinator.frameworkTranscript == nil)
        #expect(coordinator.feedback.events.isEmpty)
        #expect(!coordinator.isResponding)
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func instructionsStartWithDomain() {
        let coordinator = SBJAIAssistantCoordinator<Int>(snapshot: { nil }, domainInstructions: "The business domain is Inventory Record.")
        #expect(coordinator.instructions == "The business domain is Inventory Record.\n\n" + SBJAIInstructions.session)
        #expect(coordinator.instructions.contains("readKeys"))
        #expect(!coordinator.instructions.contains("nextOffset"))
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func rolloverRetainsTwoCompletedTurns() {
        let initial = Transcript.Entry.instructions(.init(segments: [], toolDefinitions: []))
        let first = Transcript.Entry.prompt(.init(segments: []))
        let second = Transcript.Entry.prompt(.init(segments: []))
        let third = Transcript.Entry.prompt(.init(segments: []))
        let failed = Transcript.Entry.prompt(.init(segments: []))
        let answer1 = Transcript.Entry.response(.init(segments: []))
        let answer2 = Transcript.Entry.response(.init(segments: []))
        let answer3 = Transcript.Entry.response(.init(segments: []))
        let original = Transcript(entries: [initial, first, answer1, second, answer2, third, answer3, failed])
        let condensed = SBJAIAssistantCoordinator<Int>.condensedTranscript(original)
        #expect(Array(condensed).map(\.id) == [initial, second, answer2, third, answer3].map(\.id))
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test("Initial and reset lifecycle requires no inference")
    func initialSessionStateRequiresNoInference() {
        let coordinator = SBJAIAssistantCoordinator<Int>(snapshot: { nil }, domainInstructions: "Test document.")
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
    @Test func newSessionClearsConversationWithoutDeactivating() {
        let coordinator = SBJAIAssistantCoordinator<Int>(snapshot: { nil }, domainInstructions: "Test document.")
        coordinator.activate()
        let assistant: any SBJAssistantPresenting = coordinator
        coordinator.printInstructions()
        let previousTurn = assistant.currentTurnID
        assistant.feedback.isEnabled = true
        assistant.feedback.recordCorrection(turnID: previousTurn, revision: -1, category: .wrongField)
        assistant.startNewSession()
        #expect(assistant.isActive)
        #expect(!assistant.isResponding)
        #expect(assistant.messages.isEmpty)
        #expect(assistant.frameworkDiagnostics.isEmpty)
        #expect(assistant.frameworkTranscript == nil)
        #expect(coordinator.sessionInstructions == nil)
        #expect(assistant.currentTurnID != previousTurn)
        #expect(assistant.feedback.events.isEmpty)
        #expect(assistant.feedback.isEnabled)
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test("An arbitrary root needs no structural conformance and cannot be persisted")
    func inertMutationAPI() {
        struct Root { let name: String }
        var persistCalls = 0
        let coordinator = SBJAIAssistantCoordinator<Root>(snapshot: {
            .init(id: "test", revision: 1, model: .init(name: "Test"), allowsEditing: true)
        }, persist: { _, _, _, _ in persistCalls += 1 }, domainInstructions: "Test document.")
        coordinator.activate()
        coordinator.approve()
        coordinator.reject()
        coordinator.synchronize()
        #expect(coordinator.pendingProposal == nil)
        #expect(!coordinator.canApprove)
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
        let coordinator = SBJAIAssistantCoordinator<Int>(snapshot: { nil }, domainInstructions: "Test document.")
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
        let coordinator = SBJAIAssistantCoordinator<Int>(snapshot: { nil }, persist: { _, _, _, _ in }, domainInstructions: "Test document.")
        coordinator.activate()
        coordinator.submit("   ")
        coordinator.submit("Hello")
        #expect(!coordinator.isResponding)
        #expect(coordinator.messages.isEmpty)
    }
}
#endif
