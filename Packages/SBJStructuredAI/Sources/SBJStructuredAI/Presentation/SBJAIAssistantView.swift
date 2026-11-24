#if canImport(SwiftUI) && !os(watchOS) && !os(tvOS)
import Foundation
import SwiftUI

/// A display-only conversation message. The application owns document identity,
/// conversation state and message retention; this value does not carry a model reference.
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

/// A lightweight presentation boundary. Implementations keep document revisions,
/// asynchronous model work, approval validation and persistence outside the view.
@MainActor
public protocol SBJAIAssistantPresenting: AnyObject {
    var messages: [SBJAIAssistantMessage] { get }
    var pendingProposal: SBJAIChangeSummary? { get }
    var isResponding: Bool { get }
    var isActive: Bool { get }
    var canSubmit: Bool { get }
    var canApprove: Bool { get }
    /// Optional, read-only discovery diagnostics, supplied by the host.
    var discoveryDiagnostics: [String] { get }

    func submit(_ text: String)
    func stop()
    func approve()
    func reject()
}

public extension SBJAIAssistantPresenting {
    var discoveryDiagnostics: [String] { [] }
}

/// Client-supplied presentation terminology. It does not prescribe a domain vocabulary.
public struct SBJAIAssistantLabels: Sendable {
    public var emptyTitle: String
    public var emptyDescription: String
    public var prompt: String
    public var send: String
    public var stop: String
    public var approveTitle: String
    public var approve: String
    public var reject: String
    public var resolvedField: String
    public var currentValue: String
    public var proposedValue: String
    public var readOnly: String
    public var errorPrefix: String

    public init(
        emptyTitle: String = "Ask the Assistant",
        emptyDescription: String = "Ask a question about this document.",
        prompt: String = "Message",
        send: String = "Send",
        stop: String = "Stop",
        approveTitle: String = "Review proposed changes",
        approve: String = "Apply",
        reject: String = "Cancel",
        resolvedField: String = "Field",
        currentValue: String = "Current",
        proposedValue: String = "Proposed",
        readOnly: String = "This document is read-only.",
        errorPrefix: String = ""
    ) {
        self.emptyTitle = emptyTitle
        self.emptyDescription = emptyDescription
        self.prompt = prompt
        self.send = send
        self.stop = stop
        self.approveTitle = approveTitle
        self.approve = approve
        self.reject = reject
        self.resolvedField = resolvedField
        self.currentValue = currentValue
        self.proposedValue = proposedValue
        self.readOnly = readOnly
        self.errorPrefix = errorPrefix
    }
}

/// Generic SwiftUI presentation for an AI conversation and typed change approvals.
///
/// The view never calls `SBJAIConversation` directly and never saves a document.
/// The host implements `SBJAIAssistantPresenting` to enforce its revision,
/// cancellation and approval policies. Header and input accessory slots support
/// optional feedback, dictation, and application-specific controls without making
/// those services dependencies of SBJStructuredAI.
@MainActor
public struct SBJAIAssistantView<Model: SBJAIAssistantPresenting, Header: View, InputAccessory: View>: View {
    public let assistant: Model
    @Binding private var draft: String
    private let labels: SBJAIAssistantLabels
    private let header: Header
    private let inputAccessory: InputAccessory
    @FocusState private var inputFocused: Bool
    @State private var showsDiscoveryDiagnostics = false

    public init(
        assistant: Model,
        draft: Binding<String>,
        labels: SBJAIAssistantLabels = .init(),
        @ViewBuilder header: () -> Header,
        @ViewBuilder inputAccessory: () -> InputAccessory
    ) {
        self.assistant = assistant
        _draft = draft
        self.labels = labels
        self.header = header()
        self.inputAccessory = inputAccessory()
    }

    private var canSend: Bool {
        assistant.isActive && assistant.canSubmit && !assistant.isResponding &&
        assistant.pendingProposal == nil && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if assistant.messages.isEmpty {
                            ContentUnavailableView {
                                Label(labels.emptyTitle, systemImage: "sparkles")
                            } description: {
                                Text(labels.emptyDescription)
                            }
                        }
                        ForEach(assistant.messages) { message in
                            messageView(message).id(message.id)
                        }
                        if !assistant.discoveryDiagnostics.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    showsDiscoveryDiagnostics.toggle()
                                } label: {
                                    Label("Discovery diagnostics", systemImage: "stethoscope")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                if showsDiscoveryDiagnostics {
                                    ForEach(Array(assistant.discoveryDiagnostics.enumerated()), id: \.offset) { _, line in
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
                        if let proposal = assistant.pendingProposal {
                            approvalView(proposal).id("approval")
                        }
                        if assistant.isResponding {
                            HStack {
                                ProgressView("Thinking…")
                                Spacer()
                                Button(labels.stop) { assistant.stop() }
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
                .onChange(of: assistant.pendingProposal?.id) { _, id in
                    if id != nil { withAnimation { scroll.scrollTo("approval", anchor: .bottom) } }
                }
            }
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                TextField(labels.prompt, text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .onSubmit(send)
                    .disabled(!assistant.isActive || !assistant.canSubmit || assistant.isResponding || assistant.pendingProposal != nil)
                inputAccessory
                Button(action: send) {
                    Label(labels.send, systemImage: "arrow.up.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(labels.send)
                .disabled(!canSend)
            }
            .padding()
        }
        .frame(minWidth: 320, minHeight: 300)
        .onChange(of: assistant.isActive) { _, active in
            if !active { inputFocused = false }
        }
    }

    @ViewBuilder
    private func messageView(_ message: SBJAIAssistantMessage) -> some View {
        HStack {
            if message.speaker == .user { Spacer(minLength: 45) }
            VStack(alignment: .leading, spacing: 5) {
                Text(message.speaker == .user ? "You" : message.speaker == .error ? "Error" : message.speaker == .diagnostic ? "Discovery diagnostics" : "Assistant")
                    .font(.caption).bold().foregroundStyle(.secondary)
                if message.speaker == .assistant {
                    Text((try? AttributedString(markdown: message.text)) ?? AttributedString(message.text))
                        .textSelection(.enabled)
                } else if message.speaker == .diagnostic {
                    Text(message.text)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Text(message.speaker == .error ? labels.errorPrefix + message.text : message.text)
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

    private func approvalView(_ proposal: SBJAIChangeSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(labels.approveTitle, systemImage: "checkmark.shield")
                .font(.headline)
            ForEach(Array(proposal.changes.enumerated()), id: \.offset) { _, change in
                VStack(alignment: .leading, spacing: 8) {
                    Text(change.field)
                        .font(.subheadline.weight(.semibold))
                        .textSelection(.enabled)
                        .accessibilityLabel("\(labels.resolvedField): \(change.field)")
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(labels.currentValue).font(.caption).foregroundStyle(.secondary)
                            Text(change.oldValue).monospacedDigit()
                        }
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(labels.proposedValue).font(.caption).foregroundStyle(.secondary)
                            Text(change.proposedValue).monospacedDigit()
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            HStack(spacing: 10) {
                Spacer()
                Button(labels.reject, role: .cancel) { assistant.reject() }
                    .buttonStyle(.bordered)
                    .disabled(assistant.isResponding)
                Button(labels.approve) { assistant.approve() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!assistant.isActive || !assistant.canApprove || assistant.isResponding)
            }
            if !assistant.canApprove {
                Text(labels.readOnly).font(.caption).foregroundStyle(.secondary)
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

/// No toolbar or accessory is required for basic text-only conversations.
public extension SBJAIAssistantView where Header == EmptyView, InputAccessory == EmptyView {
    init(assistant: Model, draft: Binding<String>, labels: SBJAIAssistantLabels = .init()) {
        self.init(assistant: assistant, draft: draft, labels: labels) {
            EmptyView()
        } inputAccessory: {
            EmptyView()
        }
    }
}
#endif
