import SwiftUI
import Testing
#if os(macOS)
import AppKit
#elseif canImport(UIKit) && !os(watchOS)
import UIKit
#endif
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
        host(view)
    }

    @Test func multilineConversationAndFeedbackBuildWithoutFoundationModels() {
        let assistant: any SBJAssistantPresenting = TestAssistant()
        let conversation = SBJAssistantView(assistant: assistant,
                                            options: .init(simpleCommands: false)) {
            Text("Header")
        } inputAccessory: {
            Text("Accessory")
        }
        host(conversation)
        let feedback = SBJAssistantFeedbackView(feedback: SBJAssistantFeedback(), turnID: .init(), revision: 1)
        host(feedback)
    }

    @Test func feedbackIsOptInWithoutEnablingCollection() {
        let assistant: any SBJAssistantPresenting = TestAssistant()
        #expect(!SBJAssistantViewOptions().hasFeedbackDialog)
        let options = SBJAssistantViewOptions(hasFeedbackDialog: true)
        #expect(options.hasFeedbackDialog)
        let view = SBJAssistantView(assistant: assistant, options: options)
        host(view)
        #expect(!assistant.feedback.isEnabled)
    }

    /// Evaluate stateful views through SwiftUI, never by accessing body directly.
    private func host<Content: View>(_ content: Content) {
#if os(macOS)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        hostingView.layoutSubtreeIfNeeded()
#elseif canImport(UIKit) && !os(watchOS)
        let controller = UIHostingController(rootView: content)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
#else
        // Construction-only smoke test where no hosting API is available.
        withExtendedLifetime(content) {}
#endif
    }

    @Test(arguments: [false, true])
    func resetControlIsOptIn(enabled: Bool) {
        #expect(!SBJAssistantViewOptions().hasResetButton)
        let options = SBJAssistantViewOptions(hasResetButton: enabled)
        #expect(options.hasResetButton == enabled)
        let assistant = TestAssistant()
        assistant.submit("Keep this conversation until confirmed")
        let turn = assistant.currentTurnID
        host(SBJAssistantView(assistant: assistant, options: options))
        #expect(assistant.messages.count == 1)
        #expect(assistant.currentTurnID == turn)
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
