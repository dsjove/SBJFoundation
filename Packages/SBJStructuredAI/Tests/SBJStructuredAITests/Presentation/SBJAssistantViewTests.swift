import SwiftUI
import Testing
@testable import SBJStructuredAI

@Suite("Backend-independent assistant views")
@MainActor
struct SBJAssistantViewTests {
    @Test(arguments: [SBJAssistantState.unsupported, .disabled, .preparing, .ready, .unknown])
    func conversationBuildsWithoutFoundationModels(state: SBJAssistantState) {
        let assistant = TestAssistant()
        assistant.availabilityState = state
        let options = SBJAssistantViewOptions(hasSpeechToggle: true, hasMicrophoneToggle: true,
                                             hasDiagnostics: true, hasShareDialog: true, hasFeedbackDialog: true)
        let view = SBJAssistantView(assistant: assistant, options: options)
        _ = view.body
    }

    @Test func multilineConversationAndFeedbackBuildWithoutFoundationModels() {
        let assistant: any SBJAssistantPresenting = TestAssistant()
        let conversation = SBJAssistantView(assistant: assistant,
                                            options: .init(simpleCommands: false)) {
            Text("Header")
        } inputAccessory: {
            Text("Accessory")
        }
        _ = conversation.body
        let feedback = SBJAssistantFeedbackView(feedback: SBJAssistantFeedback(), turnID: .init(), revision: 1)
        _ = feedback.body
    }

    @Test func feedbackIsOptInWithoutEnablingCollection() {
        let assistant: any SBJAssistantPresenting = TestAssistant()
        #expect(!SBJAssistantViewOptions().hasFeedbackDialog)
        let options = SBJAssistantViewOptions(hasFeedbackDialog: true)
        #expect(options.hasFeedbackDialog)
        let view = SBJAssistantView(assistant: assistant, options: options)
        _ = view.body
        #expect(!assistant.feedback.isEnabled)
    }

    @Test func unavailableControlsAreDisabled() {
        let options = SBJAssistantViewOptions(hasSpeechToggle: true, hasMicrophoneToggle: true, hasShareDialog: true)
#if !canImport(Speech) || !canImport(AVFoundation) || os(watchOS) || os(tvOS)
        #expect(!options.hasSpeechToggle)
        #expect(!options.hasMicrophoneToggle)
#else
        #expect(options.hasSpeechToggle)
        #expect(options.hasMicrophoneToggle)
#endif
#if os(tvOS)
        #expect(!options.hasShareDialog)
#else
        #expect(options.hasShareDialog)
#endif
    }
}
