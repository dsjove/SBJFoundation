import SwiftUI
import SBJLocalization

@MainActor
struct SBJAssistantComposer<Accessory: View>: View {
    private typealias N = SBJAssistantNomenclature
    @Binding var draft: String
    let inputFocused: FocusState<Bool>.Binding
    let speech: SBJAssistantSpeechController
    let simpleCommands: Bool
    let hasMicrophoneToggle: Bool
    let canEdit: Bool
    let canSend: Bool
    let inputAccessory: Accessory
    let displayError: (String) -> String
    let send: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                promptField
                inputAccessory
#if canImport(Speech) && canImport(AVFoundation) && !os(watchOS) && !os(tvOS)
                if hasMicrophoneToggle { microphoneButton }
#endif
                sendButton
            }
            .padding()
            if let error = speech.errorMessage, hasMicrophoneToggle {
                Text(displayError(error))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    private var promptField: some View {
        textField
#if !os(tvOS) && !os(watchOS)
            .textFieldStyle(.roundedBorder)
#endif
            .focused(inputFocused)
            .disabled(!canEdit)
    }

    @ViewBuilder
    private var textField: some View {
        if simpleCommands {
            TextField(N.prompt.title, text: $draft)
                .onSubmit(send)
        } else {
            TextField(N.prompt.title, text: $draft, axis: .vertical)
                .lineLimit(1...5)
        }
    }

#if canImport(Speech) && canImport(AVFoundation) && !os(watchOS) && !os(tvOS)
    private var microphoneButton: some View {
        Button {
            if speech.isListening { speech.stop() }
            else { Task { await speech.start() } }
        } label: {
            Image(systemName: speech.isListening ? "stop.circle.fill" : "mic")
        }
        .accessibilityLabel(speech.isListening ? N.stopDictation.title : N.startDictation.title)
        .disabled(!canEdit)
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
        .disabled(!canSend)
    }
}
