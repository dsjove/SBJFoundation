import Foundation
import SwiftUI
import SBJLocalization

/// Generic SwiftUI presentation for an assistant conversation.
/// The view knows only its presentation protocol and never saves a document.
/// Header and input accessory slots support
/// optional feedback, dictation, and application-specific controls without making
/// those services dependencies of SBJStructuredAI.
@MainActor
public struct SBJAssistantView<Header: View, InputAccessory: View>: View {
    public let assistant: any SBJAssistantPresenting
    @Binding private var draft: String
    private let options: SBJAssistantViewOptions
    private let header: Header
    private let inputAccessory: InputAccessory
    @FocusState private var inputFocused: Bool
    @State private var availability: SBJAssistantState
    @State private var speech = SBJAssistantSpeechController()

    public init(
        assistant: any SBJAssistantPresenting,
        draft: Binding<String>,
        options: SBJAssistantViewOptions = .init(),
        @ViewBuilder header: () -> Header,
        @ViewBuilder inputAccessory: () -> InputAccessory
    ) {
        self.assistant = assistant
        _availability = State(initialValue: assistant.availabilityState)
        _draft = draft
        self.options = options
        self.header = header()
        self.inputAccessory = inputAccessory()
    }

    private var canSend: Bool {
        availability.canChat && assistant.isActive && assistant.canSubmit && !assistant.isResponding &&
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        Group {
            if availability.canChat {
                chatBody
            } else {
                SBJAssistantAvailabilityView(state: availability,
                                             providerName: assistant.availabilityProviderName,
                                             message: assistant.availabilityMessage(for: availability))
            }
        }
        .frame(minWidth: 320, minHeight: 300)
        .task {
            while !Task.isCancelled {
                let next = assistant.availabilityState
                if next != availability {
                    if !next.canChat {
                        assistant.stop()
                        speech.reset()
                    }
                    availability = next
                }
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
            }
        }
    }

    private var chatBody: some View {
        VStack(spacing: 0) {
            header
            SBJAssistantToolbar(hasSpeechToggle: options.hasSpeechToggle,
                                hasShareDialog: options.hasShareDialog,
                                speaksResponses: $speech.speaksResponses,
                                transcript: options.hasShareDialog ? assistant.exportText : "",
                                canShare: !assistant.messages.isEmpty || !assistant.frameworkDiagnostics.isEmpty)
            SBJAssistantTranscriptView(messages: assistant.messages,
                                       diagnostics: assistant.frameworkDiagnostics,
                                       showsDiagnostics: options.hasDiagnostics,
                                       shortcuts: assistant.shortcuts,
                                       isActive: assistant.isActive,
                                       isResponding: assistant.isResponding,
                                       displayError: assistant.displayError,
                                       selectShortcut: assistant.selectShortcut,
                                       stop: assistant.stop)
            Divider()
            SBJAssistantComposer(draft: $draft, inputFocused: $inputFocused, speech: speech,
                                 simpleCommands: options.simpleCommands,
                                 hasMicrophoneToggle: options.hasMicrophoneToggle,
                                 canEdit: assistant.isActive && assistant.canSubmit && !assistant.isResponding,
                                 canSend: canSend, inputAccessory: inputAccessory,
                                 displayError: assistant.displayError, send: send)
        }
        .onChange(of: assistant.isActive) { _, active in
            if !active {
                inputFocused = false
                speech.reset()
            }
        }
        .onChange(of: assistant.isResponding) { _, responding in
            if responding { speech.stop() }
        }
        .onChange(of: speech.transcript) { _, transcript in
            if !transcript.isEmpty { draft = transcript }
        }
        .onChange(of: assistant.messages.count) { _, _ in
            guard let message = assistant.messages.last else { return }
            if message.speaker == .assistant { speech.speak(message.text) }
            if message.speaker == .error { speech.speak(assistant.displayError(message.text)) }
        }
    }

    private func send() {
        guard canSend else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        assistant.submit(text)
        draft = ""
    }
}

/// No toolbar or accessory is required for basic text-only conversations.
public extension SBJAssistantView where Header == EmptyView, InputAccessory == EmptyView {
    init(assistant: any SBJAssistantPresenting, draft: Binding<String>,
         options: SBJAssistantViewOptions = .init()) {
        self.init(assistant: assistant, draft: draft, options: options) {
            EmptyView()
        } inputAccessory: {
            EmptyView()
        }
    }
}
