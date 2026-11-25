#if canImport(FoundationModels) && canImport(SwiftUI) && !os(watchOS) && !os(tvOS)
import Foundation
import FoundationModels
import Observation

/// Read-only conversational boundary. Legacy mutation API is inert during the reset.
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
@MainActor
@Observable
public final class SBJAIAssistantCoordinator<Root>: SBJAIAssistantPresenting {
    public let feedback = SBJAIAssistantFeedback()
    public private(set) var messages: [SBJAIAssistantMessage] = []
    public var pendingProposal: SBJAIChangeSummary? { nil }
    public private(set) var isResponding = false
    public var isPersisting: Bool { false }
    public private(set) var isActive = false
    public private(set) var currentTurnID = UUID()
    public var frameworkDiagnostics: [String] { [] }
    public private(set) var frameworkTranscript: String?
    public var canSubmit: Bool { isActive && !isResponding && hasDocument && SBJAIAssistantAvailability.state == .ready }
    public var canApprove: Bool { false }
    public var canRestore: Bool { false }
    public var hasDocument: Bool { snapshot() != nil }
    public var feedbackRevision: Int { snapshot()?.revision ?? -1 }
    public var shortcuts: [SBJAIChatShortcut] { [] }

    private let snapshot: @MainActor () -> SBJAIAssistantDocument<Root>?
    private let diagnostic: (@MainActor (SBJAIAssistantDiagnostic, UUID, Int) -> Void)?
    private let errorDisplay: @MainActor (String) -> String
    private let instructions: String?
    private var session: LanguageModelSession?
    private var completedTranscript: Transcript?
    private var activeRequest: Task<Void, Never>?
    private var generation = 0

    /// Conversation-only initializer. No persistence bridge is required.
    public init(
        snapshot: @escaping @MainActor () -> SBJAIAssistantDocument<Root>?,
        instructions: String? = nil,
        diagnostic: (@MainActor (SBJAIAssistantDiagnostic, UUID, Int) -> Void)? = nil,
        displayError: @escaping @MainActor (String) -> String = { $0 }
    ) {
        self.snapshot = snapshot
        self.instructions = instructions
        self.diagnostic = diagnostic
        self.errorDisplay = displayError
    }

    /// Source-compatible initializer. The reset never invokes the persistence closure.
    public convenience init(
        snapshot: @escaping @MainActor () -> SBJAIAssistantDocument<Root>?,
        persist: @escaping @MainActor (_ updated: Root, _ expectedID: String, _ expectedRevision: Int, _ completion: @escaping @MainActor (Result<Void, Error>) -> Void) -> Void,
        instructions: String? = nil,
        diagnostic: (@MainActor (SBJAIAssistantDiagnostic, UUID, Int) -> Void)? = nil,
        displayError: @escaping @MainActor (String) -> String = { $0 }
    ) {
        self.init(snapshot: snapshot, instructions: instructions, diagnostic: diagnostic, displayError: displayError)
    }

    public func displayError(_ message: String) -> String { errorDisplay(message) }
    public func selectShortcut(_ shortcut: SBJAIChatShortcut) { submit(shortcut.reply) }

    public func activate() {
        guard !isActive else { return }
        isActive = true
        completedTranscript = nil
        messages = []
        frameworkTranscript = nil
    }

    public func deactivate() {
        guard isActive || session != nil else { return }
        invalidateRequest()
        isActive = false
        completedTranscript = nil
        session = nil
    }

    /// Host compatibility only: document changes do not drive this prototype.
    public func synchronize() {}
    public func approve() {}
    public func reject() {}
    public func restore() {}

    /// Prepare the exact session that will handle the next request. Safe before
    /// activation and during a conversation; unavailable, busy, or already-created
    /// sessions are left alone. This is a best-effort hint, not a readiness guarantee.
    public func prewarm() {
        guard SBJAIAssistantAvailability.state.canPrewarm(
            hasSession: session != nil, isResponding: isResponding
        ) else { return }
        conversationSession().prewarm()
    }

    private func conversationSession() -> LanguageModelSession {
        if let session { return session }
        let next = completedTranscript.map { LanguageModelSession(transcript: $0) }
            ?? LanguageModelSession(instructions:
                "Query values of a structured data set. No data set is connected yet. Do not invent values or claim to read or change a document."
                + (instructions.map { "\n" + $0 } ?? ""))
        session = next
        return next
    }

    public func submit(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSubmit, !question.isEmpty else { return }
        let session = conversationSession()
        generation += 1
        let request = generation
        currentTurnID = UUID()
        isResponding = true
        messages.append(.init(speaker: .user, text: question))
        activeRequest = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.generation == request {
                    self.isResponding = false
                    self.activeRequest = nil
                    self.frameworkTranscript = self.completedTranscript.map { String(describing: $0) }
                }
            }
            do {
                let response = try await session.respond(to: question)
                guard self.generation == request, !Task.isCancelled else { return }
                self.completedTranscript = session.transcript
                self.messages.append(.init(speaker: .assistant, text: response.content))
            } catch {
                guard self.generation == request, !Task.isCancelled else { return }
                self.session = nil
                self.emit("request.failed")
                self.messages.append(.init(speaker: .error, text: error.localizedDescription))
            }
        }
    }

    private func invalidateRequest() {
        generation += 1
        activeRequest?.cancel()
        activeRequest = nil
        isResponding = false
        // A cancelled native session may still be unwinding. Never reuse it.
        session = nil
    }

    public func stop() {
        guard isResponding else { return }
        invalidateRequest()
        emit("request.stopped")
        messages.append(.init(speaker: .assistant, text: "Request stopped."))
    }

    private func emit(_ code: String) {
        let event = SBJAIAssistantDiagnostic(code: code)
        feedback.record(event: event, turnID: currentTurnID, revision: feedbackRevision)
        diagnostic?(event, currentTurnID, feedbackRevision)
    }
}
#endif
