import SwiftUI
import SBJLocalization

@MainActor
struct SBJAssistantComposer<Accessory: View>: View {
    private typealias N = SBJAssistantNomenclature
    @Binding var draft: String
    let inputFocused: FocusState<Bool>.Binding
    let speech: SBJAssistantSpeechController
    let options: SBJAssistantViewOptions
    let showFeedback: () -> Void
    let transcript: String
    let canShare: Bool
    let canEdit: Bool
    let canSend: Bool
    let canStartNewSession: Bool
    let startNewSession: () -> Void
    let inputAccessory: Accessory
    let displayError: (String) -> String
    let send: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                leadingActions
                if options.hasResetButton { newSessionButton }
                promptField
                inputAccessory
#if canImport(Speech) && canImport(AVFoundation) && !os(watchOS) && !os(tvOS)
                if options.hasMicrophoneToggle { microphoneButton }
                if options.hasSpeechToggle { speechButton }
#endif
                sendButton
            }
            .padding()
            if let error = speech.errorMessage, options.hasMicrophoneToggle {
                Text(displayError(error))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    private var newSessionButton: some View {
        Button(action: startNewSession) {
            Label(N.newSession.title, systemImage: "trash.fill")
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Color.red)
        .accessibilityLabel(N.newSession.title)
#if os(macOS) || targetEnvironment(macCatalyst)
        .help(N.newSession.title)
#endif
        .disabled(!canStartNewSession)
    }

    private var promptField: some View {
        textField
#if !os(tvOS) && !os(watchOS)
            .textFieldStyle(.roundedBorder)
#endif
            .disabled(!canEdit)
    }

    @ViewBuilder
    private var textField: some View {
        if options.simpleCommands {
#if os(watchOS) || os(tvOS)
            TextField(N.prompt.title, text: $draft)
                .focused(inputFocused)
                .onSubmit(send)
#else
            if #available(iOS 18.0, macOS 15.0, macCatalyst 18.0, visionOS 2.0, *) {
                SBJAssistantCommandField(draft: $draft, inputFocused: inputFocused, send: send)
            } else {
                multilineField
                    .onKeyPress(.return, phases: .down) { press in
                        guard press.modifiers.intersection([.shift, .control, .option, .command]).isEmpty else { return .ignored }
                        send()
                        return .handled
                    }
                    .onSubmit(send)
            }
#endif
        } else {
            multilineField
        }
    }

    private var multilineField: some View {
        TextField(N.prompt.title, text: $draft, axis: .vertical)
            .lineLimit(1...5)
            .focused(inputFocused)
    }

    @ViewBuilder
    private var leadingActions: some View {
        if options.hasFeedbackDialog {
            Button(action: showFeedback) {
                Label(N.feedback.title, systemImage: "exclamationmark.bubble")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(N.feedback.title)
        }
#if !os(tvOS)
        if options.hasShareDialog {
            ShareLink(item: transcript, subject: Text(N.shareSubject.title),
                      message: Text(N.shareMessage.title)) {
                Label(N.shareTranscript.title, systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
            }
            .disabled(!canShare)
            .buttonStyle(.borderless)
            .accessibilityLabel(N.shareTranscript.accessibilityLabel ?? N.shareTranscript.title)
        }
#endif
    }

#if canImport(Speech) && canImport(AVFoundation) && !os(watchOS) && !os(tvOS)
    private var microphoneButton: some View {
        Button {
            if speech.isListening { speech.stop() }
            else { Task { await speech.start() } }
        } label: {
            Image(systemName: speech.isListening ? "stop.circle.fill" : "mic")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(speech.isListening ? N.stopDictation.title : N.startDictation.title)
        .disabled(!canEdit)
    }

    private var speechButton: some View {
        Button {
            speech.speaksResponses.toggle()
        } label: {
            Label(N.speakResponses.title,
                  systemImage: speech.speaksResponses ? "speaker.wave.2.fill" : "speaker.slash")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(N.speakResponses.title)
        .accessibilityAddTraits(speech.speaksResponses ? .isSelected : [])
    }
#endif

    private var sendButton: some View {
        Button(action: send) {
            Label(N.send.title, systemImage: "arrow.up.circle.fill")
                .labelStyle(.iconOnly)
                .font(.title2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(N.send.title)
#if !os(tvOS) && !os(watchOS)
        // A native Return shortcut also covers platforms where the multiline
        // text field does not deliver onSubmit (notably Mac Catalyst).
        .keyboardShortcut(options.simpleCommands && inputFocused.wrappedValue ? .defaultAction : nil)
#endif
        .disabled(!canSend)
    }
}
