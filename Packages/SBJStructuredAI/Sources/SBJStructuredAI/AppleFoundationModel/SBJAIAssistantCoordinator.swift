#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Foundation
import FoundationModels
import Observation

/// Read-only conversational boundary. Native tool arguments are generated from
/// the current document instance; no mutation or persistence is available.
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
@MainActor
@Observable
final class SBJAIAssistantCoordinator<Root>: SBJAssistantCoordinating, SBJAssistantPresenting {
    var availabilityState: SBJAssistantState { SBJAIAvailability.state }
    var availabilityProviderName: String? { "Apple Intelligence" }
    func availabilityMessage(for state: SBJAssistantState) -> String? {
        SBJAIAvailability.message(for: state)
    }
    let feedback = SBJAssistantFeedback()
    private(set) var messages: [SBJAssistantMessage] = []
    var pendingProposal: SBJStructuralChangeSummary? { nil }
    private(set) var isResponding = false
    private(set) var isActive = false
    private(set) var currentTurnID = UUID()
    /// Available for inspection without parsing the native session transcript.
    private(set) var structureContext: SBJAIStructureContext?
    var frameworkDiagnostics: [String] {
        guard let context = structureContext else { return [] }
        return [
            "Structure: \(context.snapshot.rootType), \(context.snapshot.paths.count) readable addresses",
            "Local document description: \(context.documentDescription.utf8.count) UTF-8 bytes (not sent to the model)",
        ] + tokenDiagnostics
    }
    private(set) var frameworkTranscript: String?
    var canSubmit: Bool { isActive && !isResponding && hasDocument && SBJAIAvailability.state == .ready }
    var canApprove: Bool { false }
    var canRestore: Bool { false }
    var hasDocument: Bool { snapshot() != nil }
    var feedbackRevision: Int { snapshot()?.revision ?? -1 }

    private let snapshot: @MainActor () -> SBJAssistantDocument<Root>?
    private let diagnostic: (@MainActor (SBJAssistantDiagnostic, UUID, Int) -> Void)?
    private let errorDisplay: @MainActor (String) -> String
    private let instructions: String?
    private var tokenDiagnostics: [String] = []
    private var session: LanguageModelSession?
    private var completedTranscript: Transcript?
    private var activeRequest: Task<Void, Never>?
    private var generation = 0
    private struct DocumentVersion: Equatable {
        let id: String
        let revision: Int
        init(_ document: SBJAssistantDocument<Root>) {
            id = document.id
            revision = document.revision
        }
    }
    private var sessionDocument: DocumentVersion?

    /// Read-only initializer. No persistence bridge is required.
    init(
        snapshot: @escaping @MainActor () -> SBJAssistantDocument<Root>?,
        instructions: String? = nil,
        diagnostic: (@MainActor (SBJAssistantDiagnostic, UUID, Int) -> Void)? = nil,
        displayError: @escaping @MainActor (String) -> String = { $0 }
    ) {
        self.snapshot = snapshot
        self.instructions = instructions
        self.diagnostic = diagnostic
        self.errorDisplay = displayError
    }

    /// Existing host initializer. The read-only session never invokes persistence.
    convenience init(
        snapshot: @escaping @MainActor () -> SBJAssistantDocument<Root>?,
        persist: @escaping @MainActor (_ updated: Root, _ expectedID: String, _ expectedRevision: Int, _ completion: @escaping @MainActor (Result<Void, Error>) -> Void) -> Void,
        instructions: String? = nil,
        diagnostic: (@MainActor (SBJAssistantDiagnostic, UUID, Int) -> Void)? = nil,
        displayError: @escaping @MainActor (String) -> String = { $0 }
    ) {
        self.init(snapshot: snapshot, instructions: instructions, diagnostic: diagnostic, displayError: displayError)
    }

    func displayError(_ message: String) -> String { errorDisplay(message) }

    func activate() {
        guard !isActive else { return }
        isActive = true
        completedTranscript = nil
        messages = []
        frameworkTranscript = nil
    }

    func deactivate() {
        guard isActive || session != nil || structureContext != nil else { return }
        invalidateRequest()
        isActive = false
        clearDocumentContext()
    }

    /// Native tool parameters belong to one document version. A different
    /// document/revision requires a new schema and a new conversation context.
    func synchronize() {
        guard let previous = sessionDocument else { return }
        let current = snapshot().map(DocumentVersion.init)
        guard current != previous else { return }
        let wasResponding = isResponding
        invalidateRequest()
        clearDocumentContext()
        if current?.id != previous.id {
            messages = []
        } else if wasResponding {
            messages.append(.init(speaker: .error, text: "The document changed during the query. Ask again to read the current values."))
        }
    }
    func approve() {}
    func reject() {}
    func restore() {}

    /// Prepare the exact session that will handle the next request. Safe before
    /// activation and during a conversation; unavailable, busy, or already-created
    /// sessions are left alone. This is a best-effort hint, not a readiness guarantee.
    func prewarm() {
        guard SBJAIAvailability.state == .ready, !isResponding else { return }
        synchronize()
        guard let document = snapshot(), SBJAIAvailability.state.canPrewarm(
            hasSession: session != nil, isResponding: isResponding
        ) else { return }
        // Schema construction can fail independently of model availability.
        // A best-effort warm-up must not add a message; submit reports the error.
        if let next = try? conversationSession(for: document) { next.prewarm() }
    }

    private func sessionInstructions(_ context: SBJAIStructureContext) -> String {
        context.instructions + (instructions.map { "\n" + $0 } ?? "")
    }

    private func conversationSession(for document: SBJAssistantDocument<Root>) throws -> LanguageModelSession {
        let version = DocumentVersion(document)
        if sessionDocument != version {
            clearDocumentContext()
            let context = try SBJAISchemaBuilder.prepare(for: document.model)
            structureContext = context
            sessionDocument = version
        }
        if let session { return session }
        // The context was constructed above (or retained for this exact version).
        guard let context = structureContext else { throw SBJSemanticReadError.noPaths }
        let tools: [any Tool] = [SBJAIReadTool(context: context)]
        let next = completedTranscript.map { LanguageModelSession(tools: tools, transcript: $0) }
            ?? LanguageModelSession(tools: tools, instructions: sessionInstructions(context))
        session = next
        return next
    }

    /// Native measurements are independent; the full schema and diagnostic text
    /// remain local and are not added to the live session's input. Failure to
    /// measure a component must not prevent normal inference.
    private func measureContext(_ context: SBJAIStructureContext, prompt: String) async -> [String] {
        let model = SystemLanguageModel.default
        let tools: [any Tool] = [SBJAIReadTool(context: context)]
        let text = sessionInstructions(context)
        var lines = ["Model context capacity: \(model.contextSize) tokens"]
        func measure(_ label: String, _ count: @MainActor () async throws -> Int) async {
            guard !Task.isCancelled else { return }
            do { lines.append("\(label): \(try await count()) tokens") }
            catch { lines.append("\(label): measurement failed (\(error.localizedDescription))") }
        }
        await measure("Instructions") { try await model.tokenCount(for: Instructions { text }) }
        await measure("Native query parameter schema") { try await model.tokenCount(for: context.readParameters) }
        await measure("Registered tool (includes query schema)") { try await model.tokenCount(for: tools) }
        await measure("First question") { try await model.tokenCount(for: prompt) }
        await measure("Complete native document schema (local only)") { try await model.tokenCount(for: context.documentSchema) }
        await measure("Human-readable document description (local only)") { try await model.tokenCount(for: context.documentDescription) }
        return lines
    }

    func submit(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Do not accept a new request while a prior native request is active.
        guard !isResponding else { return }
        synchronize()
        guard canSubmit, !question.isEmpty, let document = snapshot() else { return }
        let version = DocumentVersion(document)
        generation += 1
        let request = generation
        currentTurnID = UUID()
        isResponding = true
        messages.append(.init(speaker: .user, text: question))
        activeRequest = Task { [weak self] in
            guard let self, self.generation == request, !Task.isCancelled else { return }
            defer {
                if self.generation == request {
                    self.isResponding = false
                    self.activeRequest = nil
                    self.frameworkTranscript = self.completedTranscript.map { String(describing: $0) }
                }
            }
            do {
                // The host may change documents before this task starts. Never
                // build or answer against a stale captured document version.
                guard self.snapshot().map(DocumentVersion.init) == version else {
                    self.discardStaleDocument(version)
                    self.messages.append(.init(speaker: .error, text: "The document changed before the query. Ask again."))
                    return
                }
                let session = try self.conversationSession(for: document)
                // Measure the actual input components and the independent complete
                // schema once per document revision. Never insert the full schema
                // or a textual copy into the conversation just to measure it.
                let prompt = question
                if self.tokenDiagnostics.isEmpty, let context = self.structureContext {
                    let measured = await self.measureContext(context, prompt: prompt)
                    guard self.generation == request, !Task.isCancelled else { return }
                    guard self.snapshot().map(DocumentVersion.init) == version else {
                        self.discardStaleDocument(version)
                        self.messages.append(.init(speaker: .error, text: "The document changed before the query. Ask again."))
                        return
                    }
                    self.tokenDiagnostics = measured
                }
                let response = try await session.respond(to: prompt)
                guard self.generation == request, !Task.isCancelled else { return }
                guard self.snapshot().map(DocumentVersion.init) == version else {
                    self.discardStaleDocument(version)
                    self.messages.append(.init(speaker: .error, text: "The document changed during the query. Ask again to read the current values."))
                    return
                }
                self.completedTranscript = session.transcript
                self.messages.append(.init(speaker: .assistant, text: response.content))
            } catch {
                guard self.generation == request, !Task.isCancelled else { return }
                self.session = nil
                if self.snapshot().map(DocumentVersion.init) != version {
                    self.discardStaleDocument(version)
                    self.messages.append(.init(speaker: .error, text: "The document changed during the query. Ask again."))
                } else {
                    self.emit("request.failed")
                    if let modelError = error as? LanguageModelError,
                       case .contextSizeExceeded(let details) = modelError {
                        self.messages.append(.init(speaker: .error, text:
                            "Model context exceeded (\(details.tokenCount) tokens; limit \(details.contextSize)). Instructions, tools, conversation and read results share this limit. The full document schema is not submitted. Reset the conversation or request a smaller result."))
                    } else {
                        self.messages.append(.init(speaker: .error, text: error.localizedDescription))
                    }
                }
            }
        }
    }

    private func discardStaleDocument(_ version: DocumentVersion) {
        if snapshot()?.id != version.id { messages = [] }
        clearDocumentContext()
    }

    private func clearDocumentContext() {
        session = nil
        sessionDocument = nil
        structureContext = nil
        tokenDiagnostics = []
        completedTranscript = nil
        frameworkTranscript = nil
    }

    private func invalidateRequest() {
        generation += 1
        activeRequest?.cancel()
        activeRequest = nil
        isResponding = false
        // A cancelled native session may still be unwinding. Never reuse it.
        session = nil
    }

    func stop() {
        guard isResponding else { return }
        invalidateRequest()
        emit("request.stopped")
        messages.append(.init(speaker: .assistant, text: "Request stopped."))
    }

    private func emit(_ code: String) {
        let event = SBJAssistantDiagnostic(code: code)
        feedback.record(event: event, turnID: currentTurnID, revision: feedbackRevision)
        diagnostic?(event, currentTurnID, feedbackRevision)
    }
}
#endif
