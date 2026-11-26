import Observation
import SBJLocalization
import Testing
@testable import SBJStructuredAI

@MainActor
@Observable
final class TestAssistant: SBJAssistantPresenting {
    var availabilityState: SBJAssistantState = .ready
    var messages: [SBJAssistantMessage] = []
    var pendingProposal: SBJStructuralChangeSummary? { nil }
    var isResponding = false
    var isActive = true
    var canSubmit: Bool { isActive && availabilityState.canChat && !isResponding }
    var canApprove: Bool { false }
    var frameworkDiagnostics: [String] = []
    var frameworkTranscript: String?
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
