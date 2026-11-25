#if canImport(SwiftUI) && canImport(Speech) && canImport(AVFoundation) && !os(watchOS) && !os(tvOS)
import Foundation
import SwiftUI
import SBJLocalization

/// A display-only conversation message. The reusable coordinator owns message
/// retention; this value does not carry a document model reference.
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
public struct SBJAIAssistantMessage: Identifiable, Equatable, Sendable {
    public enum Speaker: Sendable, Equatable { case user, assistant, error, diagnostic }


    public let id: UUID
    public let speaker: Speaker
    public let text: String

    public init(id: UUID = UUID(), speaker: Speaker, text: String) {
        self.id = id
        self.speaker = speaker
        self.text = text
    }
}

/// Each message kind owns its presentation nomenclature, as in other SBJFoundation models.
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
public extension SBJAIAssistantMessage.Speaker {
    var nomenclature: SBJNomenclature {
        switch self {
        case .user: SBJAIAssistantNomenclature.speakerUser
        case .assistant: SBJAIAssistantNomenclature.speakerAssistant
        case .error: SBJAIAssistantNomenclature.speakerError
        case .diagnostic: SBJAIAssistantNomenclature.speakerDiagnostic
        }
    }
}

/// Reusable presentation switches. A host can expose only the controls it wants.
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
public struct SBJAIAssistantViewOptions: Sendable, Equatable {
    public var hasSpeechToggle: Bool
    public var hasMicrophoneToggle: Bool
    public var hasDiagnostics: Bool
    public var hasShareDialog: Bool
    /// When enabled (default), Return submits the draft. Disable for multiline Return input.
    public var simpleCommands: Bool

    public init(hasSpeechToggle: Bool = false, hasMicrophoneToggle: Bool = false,
                hasDiagnostics: Bool = false, hasShareDialog: Bool = false,
                simpleCommands: Bool = true) {
        self.hasSpeechToggle = hasSpeechToggle
        self.hasMicrophoneToggle = hasMicrophoneToggle
        self.hasDiagnostics = hasDiagnostics
        self.hasShareDialog = hasShareDialog
        self.simpleCommands = simpleCommands
    }
}

/// A deterministic reply shortcut shown in the conversation. The ID is stable
/// within the host's current choice set. The host decides what the selection means.
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
public struct SBJAIChatShortcut: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let reply: String

    public init(id: String, title: String, reply: String) {
        self.id = id
        self.title = title
        self.reply = reply
    }
}

/// A lightweight presentation boundary. Legacy approval members remain for source compatibility.
@MainActor
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
public protocol SBJAIAssistantPresenting: AnyObject {
    var messages: [SBJAIAssistantMessage] { get }
    var pendingProposal: SBJAIChangeSummary? { get }
    var isResponding: Bool { get }
    var isPersisting: Bool { get }
    var isActive: Bool { get }
    var canSubmit: Bool { get }
    var canApprove: Bool { get }
    /// Optional, read-only discovery diagnostics, supplied by the host.
    var discoveryDiagnostics: [String] { get }
    /// Framework tool calls, arguments, results and failures supplied by the host.
    /// May contain document values. Shown only when diagnostics are expanded.
    var frameworkDiagnostics: [String] { get }
    /// Optional raw Apple transcript supplied by the host, for export.
    var frameworkTranscript: String? { get }

    func submit(_ text: String)
    func stop()
    func approve()
    func reject()
    /// Current structured reply choices; for example, ambiguity resolution.
    var shortcuts: [SBJAIChatShortcut] { get }
    /// Called for a shortcut; default behavior is equivalent to submitting its reply.
    func selectShortcut(_ shortcut: SBJAIChatShortcut)
    /// Hosts can customize errors without modifying the generic view.
    func displayError(_ message: String) -> String
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
public extension SBJAIAssistantPresenting {
    var isPersisting: Bool { false }
    var discoveryDiagnostics: [String] { [] }
    var frameworkDiagnostics: [String] { discoveryDiagnostics }
    var frameworkTranscript: String? { nil }
    var shortcuts: [SBJAIChatShortcut] { [] }
    func selectShortcut(_ shortcut: SBJAIChatShortcut) { submit(shortcut.reply) }
    func displayError(_ message: String) -> String { message }
}

/// Generic SwiftUI presentation for an AI conversation.
/// The view never calls Foundation Models directly or saves a document.
/// Header and input accessory slots support
/// optional feedback, dictation, and application-specific controls without making
/// those services dependencies of SBJStructuredAI.
@MainActor
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
public struct SBJAIAssistantView<Model: SBJAIAssistantPresenting, Header: View, InputAccessory: View>: View {
    public let assistant: Model
    private typealias N = SBJAIAssistantNomenclature
    @Binding private var draft: String
    private let options: SBJAIAssistantViewOptions
    private let header: Header
    private let inputAccessory: InputAccessory
    @FocusState private var inputFocused: Bool
    @State private var showsFrameworkDiagnostics = false
    @State private var availability = SBJAIAssistantAvailability.state
    @State private var speech = SBJAISpeechController()

    private var exportText: String {
        var lines: [String] = ["SBJStructuredAI Conversation", ""]
        for message in assistant.messages {
            let speaker: String
            switch message.speaker {
            case .user: speaker = N.speakerUser.title
            case .assistant: speaker = N.speakerAssistant.title
            case .error: speaker = N.speakerError.title
            case .diagnostic: speaker = "Diagnostic"
            }
            lines.append("\(speaker):\n\(message.text)\n")
        }
        if !assistant.frameworkDiagnostics.isEmpty {
            lines.append("\n--- Tool diagnostics ---\n")
            lines.append(contentsOf: assistant.frameworkDiagnostics)
        }
        if let transcript = assistant.frameworkTranscript {
            lines.append("\n--- Apple Foundation Models transcript ---\n")
            lines.append(transcript)
        }
        return lines.joined(separator: "\n")
    }

    public init(
        assistant: Model,
        draft: Binding<String>,
        options: SBJAIAssistantViewOptions = .init(),
        @ViewBuilder header: () -> Header,
        @ViewBuilder inputAccessory: () -> InputAccessory
    ) {
        self.assistant = assistant
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
                SBJAIAssistantAvailabilityView(state: availability)
            }
        }
        .frame(minWidth: 320, minHeight: 300)
        .task {
            while !Task.isCancelled {
                let next = SBJAIAssistantAvailability.state
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
            HStack {
                if options.hasSpeechToggle {
                    Toggle(N.speakResponses.title, isOn: $speech.speaksResponses)
                        .toggleStyle(.switch)
                }
                Spacer()
                if options.hasShareDialog {
                ShareLink(item: exportText, subject: Text(N.shareSubject.title),
                          message: Text(N.shareMessage.title)) {
                    Label(N.shareTranscript.title, systemImage: "square.and.arrow.up")
                }
                .disabled(assistant.messages.isEmpty && assistant.frameworkDiagnostics.isEmpty)
                .buttonStyle(.borderless)
                .accessibilityLabel(N.shareTranscript.accessibilityLabel!)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if assistant.messages.isEmpty {
                            ContentUnavailableView {
                                Label(N.emptyTitle.title, systemImage: "sparkles")
                            } description: {
                                Text(N.emptyDescription.title)
                            }
                        }
                        ForEach(assistant.messages) { message in
                            messageView(message).id(message.id)
                        }
                        if options.hasDiagnostics && !assistant.frameworkDiagnostics.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    showsFrameworkDiagnostics.toggle()
                                } label: {
                                    Label(N.foundationModelsDiagnostics.title, systemImage: "stethoscope")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                if showsFrameworkDiagnostics {
                                    ForEach(Array(assistant.frameworkDiagnostics.enumerated()), id: \.offset) { _, line in
                                        Text(line)
                                            .font(.system(.caption2, design: .monospaced))
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                        }
                        if !assistant.shortcuts.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(assistant.shortcuts) { shortcut in
                                    Button(shortcut.title) { assistant.selectShortcut(shortcut) }
                                        .buttonStyle(.bordered)
                                        .disabled(!assistant.isActive || assistant.isResponding)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if assistant.isResponding {
                            HStack {
                                ProgressView(N.thinking.title)
                                Spacer()
                                Button(N.stop.title) { assistant.stop() }
                                    .buttonStyle(.bordered)
                            }.id("responding")
                        }
                    }
                    .padding()
                }
                .onChange(of: assistant.messages.count) { _, _ in
                    if let id = assistant.messages.last?.id {
                        withAnimation { scroll.scrollTo(id, anchor: .bottom) }
                    }
                }
                .onChange(of: assistant.isResponding) { _, responding in
                    if responding { withAnimation { scroll.scrollTo("responding", anchor: .bottom) } }
                }

            }
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                if options.simpleCommands {
                    TextField(N.prompt.title, text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .focused($inputFocused)
                        .onSubmit(send)
                        .disabled(!assistant.isActive || !assistant.canSubmit || assistant.isResponding)
                } else {
                    TextField(N.prompt.title, text: $draft, axis: .vertical)
                        .lineLimit(1...5)
                        .textFieldStyle(.roundedBorder)
                        .focused($inputFocused)
                        .disabled(!assistant.isActive || !assistant.canSubmit || assistant.isResponding)
                }
                inputAccessory
                if options.hasMicrophoneToggle {
                    Button {
                        if speech.isListening { speech.stop() }
                        else { Task { await speech.start() } }
                    } label: {
                        Image(systemName: speech.isListening ? "stop.circle.fill" : "mic")
                    }
                    .accessibilityLabel(speech.isListening ? N.stopDictation.title : N.startDictation.title)
                    .disabled(!assistant.isActive || !assistant.canSubmit || assistant.isResponding)
                }
                Button(action: send) {
                    Label(N.send.title, systemImage: "arrow.up.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(N.send.title)
                .disabled(!canSend)
            }
            .padding()
            if let error = speech.errorMessage, options.hasMicrophoneToggle {
                Text(assistant.displayError(error)).font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .frame(minWidth: 320, minHeight: 300)
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

    @ViewBuilder
    private func messageView(_ message: SBJAIAssistantMessage) -> some View {
        HStack {
            if message.speaker == .user { Spacer(minLength: 45) }
            VStack(alignment: .leading, spacing: 5) {
                Text(message.speaker.nomenclature.title)
                    .font(.caption).bold().foregroundStyle(.secondary)
                if message.speaker == .assistant {
                    Text((try? AttributedString(markdown: message.text)) ?? AttributedString(message.text))
                        .textSelection(.enabled)
                } else if message.speaker == .diagnostic {
                    Text(message.text)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Text(message.speaker == .error ? assistant.displayError(message.text) : message.text)
                        .textSelection(.enabled)
                }
            }
            .padding(12)
            .background(message.speaker == .user ? Color.accentColor.opacity(0.12)
                        : message.speaker == .diagnostic ? Color.orange.opacity(0.07)
                        : Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            if message.speaker != .user { Spacer(minLength: 45) }
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
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
public extension SBJAIAssistantView where Header == EmptyView, InputAccessory == EmptyView {
    init(assistant: Model, draft: Binding<String>,
         options: SBJAIAssistantViewOptions = .init()) {
        self.init(assistant: assistant, draft: draft, options: options) {
            EmptyView()
        } inputAccessory: {
            EmptyView()
        }
    }
}
#endif
