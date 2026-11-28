import Foundation
import Observation
import SBJLocalization
import Testing
@testable import SBJStructuredAI

@MainActor
@Observable
final class TestAssistant: SBJAssistantPresenting {
    let feedback = SBJAssistantFeedback()
    var currentTurnID = UUID()
    var feedbackRevision = 1
    var availabilityState: SBJAssistantState = .ready
    var messages: [SBJAssistantMessage] = []
    var pendingProposal: SBJStructuralChangeSummary? { nil }
    var isResponding = false
    var isActive = true
    var canSubmit: Bool { isActive && availabilityState.canChat && !isResponding }
    var canApprove: Bool { false }
    var frameworkDiagnostics: [String] = []
    var frameworkTranscript: String?
    func startNewSession() {
        messages.removeAll()
        frameworkDiagnostics.removeAll()
        frameworkTranscript = nil
        isResponding = false
        currentTurnID = UUID()
        feedback.deleteAll()
    }
    func submit(_ text: String) { messages.append(.init(speaker: .user, text: text)) }
    func stop() { isResponding = false }
    func approve() {}
    func reject() {}
}

@Suite("Backend-independent assistant presentation contract")
@MainActor
struct SBJAssistantPresentingTests {
    @Test func existentialPresentationPreservesObservation() async {
        let implementation = TestAssistant()
        let assistant: any SBJAssistantPresenting = implementation
        await confirmation("Presentation sees message changes") { changed in
            withObservationTracking {
                _ = assistant.messages
            } onChange: {
                changed()
            }
            assistant.submit("Observed through the protocol")
        }
    }

    @Test func presentationOwnsFeedbackContext() {
        let implementation = TestAssistant()
        let assistant: any SBJAssistantPresenting = implementation
        #expect(assistant.feedback === implementation.feedback)
        #expect(!assistant.feedback.isEnabled)
        assistant.feedback.isEnabled = true
        assistant.feedback.recordCorrection(turnID: assistant.currentTurnID,
                                            revision: assistant.feedbackRevision,
                                            category: .wrongField)
        #expect(assistant.feedback.events.count == 1)
        #expect(assistant.feedback.events.first?.turnID == implementation.currentTurnID)
        #expect(assistant.feedback.events.first?.documentRevision == implementation.feedbackRevision)
    }

    @Test func defaultShortcutSubmitsReply() {
        let assistant = TestAssistant()
        assistant.selectShortcut(.init(id: "choice", title: "Choice", reply: "Reply"))
        #expect(assistant.messages.map(\.text) == ["Reply"])
        #expect(!assistant.isPersisting)
        #expect(assistant.availabilityProviderName == nil)
        #expect(assistant.availabilityMessage(for: .disabled) == nil)
        #expect(assistant.displayError("Example") == "Example")
    }

    @Test func transcriptUsesCanonicalSpeakerLabelsAndBackendDiagnostics() {
        let assistant = TestAssistant()
        assistant.messages = [
            .init(speaker: .user, text: "Question"),
            .init(speaker: .assistant, text: "Answer"),
            .init(speaker: .error, text: "Failure"),
            .init(speaker: .diagnostic, text: "Event"),
        ]
        assistant.frameworkDiagnostics = ["Tool detail"]
        assistant.frameworkTranscript = "Native log"
        let transcript = assistant.exportText
        for message in assistant.messages {
            #expect(transcript.contains("\(message.speaker.nomenclature.title):\n\(message.text)"))
        }
        #expect(transcript.contains("Tool detail"))
        #expect(transcript.contains("Native log"))
    }
}
