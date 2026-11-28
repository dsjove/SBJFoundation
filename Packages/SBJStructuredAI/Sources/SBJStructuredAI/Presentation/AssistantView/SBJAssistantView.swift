import Foundation
import SwiftUI
import SBJLocalization

/// Generic SwiftUI presentation for an assistant conversation.
/// The view knows only its presentation protocol and never saves a document.
/// Header and input accessory slots support
/// application-specific controls. Feedback presentation is owned by this view.
@MainActor
public struct SBJAssistantView<Header: View, InputAccessory: View>: View {
    public let assistant: any SBJAssistantPresenting
    @State private var draft = ""
    private let options: SBJAssistantViewOptions
    private let header: Header
    private let inputAccessory: InputAccessory
    @FocusState private var inputFocused: Bool
    @State private var availability: SBJAssistantState
    @State private var speech = SBJAssistantSpeechController()
    @State private var showFeedback = false
    @State private var showResetConfirmation = false

    public init(
        assistant: any SBJAssistantPresenting,
        options: SBJAssistantViewOptions = .init(),
        @ViewBuilder header: () -> Header,
        @ViewBuilder inputAccessory: () -> InputAccessory
    ) {
        self.assistant = assistant
        _availability = State(initialValue: assistant.availabilityState)
        self.options = options
        self.header = header()
        self.inputAccessory = inputAccessory()
    }

    private var canSend: Bool {
        availability.canChat && assistant.isActive && assistant.canSubmit && !assistant.isResponding &&
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canReset: Bool {
        options.hasResetButton && availability.canChat && assistant.availabilityState.canChat &&
        assistant.isActive && !assistant.isPersisting
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
        .sheet(isPresented: $showFeedback) {
            SBJAssistantFeedbackView(
                feedback: assistant.feedback,
                turnID: assistant.currentTurnID,
                revision: assistant.feedbackRevision
            )
        }
        .alert(N.resetConfirmationTitle.title, isPresented: $showResetConfirmation) {
            Button(N.reject.title, role: .cancel) { }
            Button(N.newSession.title, role: .destructive) { startNewSession() }
        } message: {
            Text(N.resetConfirmationMessage.title)
        }
        .onChange(of: canReset) { _, enabled in
            if !enabled { showResetConfirmation = false }
        }
        .onChange(of: options.hasFeedbackDialog) { _, enabled in
            if !enabled { showFeedback = false }
        }
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
            SBJAssistantTranscriptView(messages: assistant.messages,
                                       diagnostics: assistant.frameworkDiagnostics,
                                       showsDiagnostics: options.hasDiagnostics,
                                       canPrintInstructions: assistant.canPrintInstructions,
                                       printInstructions: assistant.printInstructions,
                                       shortcuts: assistant.shortcuts,
                                       isActive: assistant.isActive,
                                       isResponding: assistant.isResponding,
                                       displayError: assistant.displayError,
                                       selectShortcut: assistant.selectShortcut,
                                       stop: assistant.stop)
            if let proposal = assistant.pendingProposal {
                approvalView(proposal)
            }
            if assistant.isPersisting { ProgressView() }
            Divider()
            SBJAssistantComposer(draft: $draft, inputFocused: $inputFocused, speech: speech,
                                 options: options,
                                 showFeedback: { showFeedback = true },
                                 transcript: options.hasShareDialog ? assistant.exportText : "",
                                 canShare: !assistant.messages.isEmpty || !assistant.frameworkDiagnostics.isEmpty,
                                 canEdit: assistant.isActive && assistant.canSubmit && !assistant.isResponding,
                                 canSend: canSend,
                                 canStartNewSession: canReset,
                                 startNewSession: { if canReset { showResetConfirmation = true } },
                                 inputAccessory: inputAccessory,
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

    private func startNewSession() {
        guard canReset else { return }
        speech.reset()
        draft = ""
        showFeedback = false
        assistant.startNewSession()
        inputFocused = assistant.canSubmit
    }

    private typealias N = SBJAssistantNomenclature

    private func approvalView(_ proposal: SBJStructuralChangeSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(N.approveTitle.title, systemImage: "checkmark.shield")
                .font(.headline)
            ScrollView {
                ForEach(Array(proposal.changes.enumerated()), id: \.offset) { _, change in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(change.field)
                            .font(.subheadline.weight(.semibold))
                            .textSelection(.enabled)
                            .accessibilityLabel("\(N.resolvedField.title): \(change.field)")
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(N.currentValue.title).font(.caption).foregroundStyle(.secondary)
                                Text(change.oldValue).monospacedDigit()
                            }
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(N.proposedValue.title).font(.caption).foregroundStyle(.secondary)
                                Text(change.proposedValue).monospacedDigit()
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .frame(maxHeight: 220)
            HStack(spacing: 10) {
                Spacer()
                Button(N.reject.title, role: .cancel) { assistant.reject() }
                    .buttonStyle(.bordered)
                    .disabled(assistant.isPersisting)
                Button(N.approve.title) { assistant.approve() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!assistant.isActive || !assistant.canApprove || assistant.isPersisting)
            }
            if !assistant.canApprove {
                Text(N.readOnly.title).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func send() {
        guard canSend else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        assistant.submit(text)
        draft = ""
    }
}

/// No host-provided header or accessory is required for basic conversations.
public extension SBJAssistantView where Header == EmptyView, InputAccessory == EmptyView {
    init(assistant: any SBJAssistantPresenting, options: SBJAssistantViewOptions = .init()) {
        self.init(assistant: assistant, options: options) {
            EmptyView()
        } inputAccessory: {
            EmptyView()
        }
    }
}
