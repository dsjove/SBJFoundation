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
    private(set) var structureContext: SBJSemanticReadSnapshot?
    var frameworkDiagnostics: [String] {
        guard let context = structureContext else { return [] }
        return [
            "Static structure (Milestone 1.3): \(context.rootType), \(context.declarationCount) declarations, \(context.entries.count) snapshot nodes",
            "Complete compact structure: \(context.structuralDescription().utf8.count) UTF-8 bytes",
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
    let instructions: String
    private var tokenDiagnostics: [String] = []
    private let domainInstructions: String
    private var session: LanguageModelSession?
    private var preparationTask: Task<Void, Error>?
    private var preparationID: UUID?
    private(set) var sessionInstructions: String?
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
        domainInstructions: String,
        diagnostic: (@MainActor (SBJAssistantDiagnostic, UUID, Int) -> Void)? = nil,
        displayError: @escaping @MainActor (String) -> String = { $0 }
    ) {
        self.snapshot = snapshot
        self.domainInstructions = domainInstructions
        self.instructions = domainInstructions + "\n\n" + SBJSemanticReadSnapshot.instructions
        self.diagnostic = diagnostic
        self.errorDisplay = displayError
    }

    /// Existing host initializer. The read-only session never invokes persistence.
    convenience init(
        snapshot: @escaping @MainActor () -> SBJAssistantDocument<Root>?,
        persist: @escaping @MainActor (_ updated: Root, _ expectedID: String, _ expectedRevision: Int, _ completion: @escaping @MainActor (Result<Void, Error>) -> Void) -> Void,
        domainInstructions: String,
        diagnostic: (@MainActor (SBJAssistantDiagnostic, UUID, Int) -> Void)? = nil,
        displayError: @escaping @MainActor (String) -> String = { $0 }
    ) {
        self.init(snapshot: snapshot, domainInstructions: domainInstructions, diagnostic: diagnostic, displayError: displayError)
    }

    func displayError(_ message: String) -> String { errorDisplay(message) }

    func activate() {
        guard !isActive else { return }
        isActive = true
        completedTranscript = nil
        messages = []
        frameworkTranscript = nil
        prewarm()
    }

    func deactivate() {
        guard isActive || session != nil || structureContext != nil else { return }
        invalidateRequest()
        isActive = false
        clearDocumentContext()
    }

    /// Native tools capture an immutable snapshot for one document version.
    /// A different document/revision requires a new snapshot and session.
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
        // The actual session is created only after the native tokenizer has
        // selected a structural representation that leaves space for inference.
        _ = try? startPreparation(for: document)
    }

    private func startPreparation(for document: SBJAssistantDocument<Root>) throws -> Task<Void, Error>? {
        let version = DocumentVersion(document)
        if sessionDocument != version {
            clearDocumentContext()
            structureContext = try SBJSemanticReadSnapshot(instance: document.model)
            sessionDocument = version
        }
        if session != nil { return nil }
        if let preparationTask { return preparationTask }
        guard let context = structureContext else { throw SBJSemanticReadError.noDocument }
        let tools: [any Tool] = [SBJAIReadValueTool(snapshot: context), SBJAIReadKeysTool(snapshot: context)]
        if let sessionInstructions {
            installSession(tools: tools, text: sessionInstructions)
            return nil
        }
        let id = UUID()
        preparationID = id
        let task = Task<Void, Error> { @MainActor [weak self] in
            guard let self else { throw CancellationError() }
            defer {
                if self.preparationID == id {
                    self.preparationTask = nil
                    self.preparationID = nil
                }
            }
            let selected = try await self.prepareInstructions(context, tools: tools)
            try Task.checkCancellation()
            guard self.preparationID == id, self.sessionDocument == version,
                  self.snapshot().map(DocumentVersion.init) == version else { throw CancellationError() }
            self.sessionInstructions = selected.text
            self.tokenDiagnostics = selected.diagnostics
            self.installSession(tools: tools, text: selected.text)
        }
        preparationTask = task
        return task
    }

    private func installSession(tools: [any Tool], text: String) {
        let next = completedTranscript.map { LanguageModelSession(tools: tools, transcript: $0) }
            ?? LanguageModelSession(tools: tools, instructions: text)
        session = next
        next.prewarm()
    }

    private func conversationSession(for document: SBJAssistantDocument<Root>) async throws -> LanguageModelSession {
        let preparation = try startPreparation(for: document)
        try await preparation?.value
        try Task.checkCancellation()
        guard sessionDocument == DocumentVersion(document), let session else { throw CancellationError() }
        return session
    }

    var canPrintInstructions: Bool { hasDocument && !isResponding }

    /// Inspect the exact candidate instructions, even before native session installation.
    /// Local conversation diagnostic only; do not send to the model or feedback collector.
    func printInstructions() {
        guard canPrintInstructions, let document = snapshot() else { return }
        do {
            let context: SBJSemanticReadSnapshot
            if sessionDocument == DocumentVersion(document), let existing = structureContext {
                context = existing
            } else {
                context = try SBJSemanticReadSnapshot(instance: document.model)
            }
            let text = completeInstructions(context)
            messages.append(.init(speaker: .diagnostic, text: text))
        } catch {
            messages.append(.init(speaker: .diagnostic, text: error.localizedDescription))
        }
    }

    private func completeInstructions(_ context: SBJSemanticReadSnapshot, usesTemplates: Bool = true) -> String {
        instructions + "\n\n" + context.structuralDescription(usesTemplates: usesTemplates)
    }

    /// Measure the complete tree before prewarming. Never silently truncate it.
    private func prepareInstructions(_ context: SBJSemanticReadSnapshot, tools: [any Tool]) async throws -> (text: String, diagnostics: [String]) {
        let model = SystemLanguageModel.default
        let toolTokens = try await model.tokenCount(for: tools)
        let base = instructions
        let baseTokens = try await model.tokenCount(for: Instructions { base })
        let full = completeInstructions(context)
        let fullTokens = try await model.tokenCount(for: Instructions { full })
        let expanded = completeInstructions(context, usesTemplates: false)
        let expandedTokens = expanded == full ? fullTokens : try await model.tokenCount(for: Instructions { expanded })
        let appTokens = try await model.tokenCount(for: Instructions { domainInstructions })
        let packageTokens = try await model.tokenCount(for: Instructions { SBJSemanticReadSnapshot.instructions })
        let structure = context.structuralDescription(usesTemplates: true)
        let structureTokens = try await model.tokenCount(for: Instructions { structure })
        let total = fullTokens + toolTokens
        let fits = total < model.contextSize
        let diagnostics = [
            "Static declarations: \(context.declarationCount)",
            "Snapshot nodes: \(context.entries.count)",
            "Estimated remaining context: \(model.contextSize - total) tokens",
            "Model context capacity: \(model.contextSize) tokens",
            "Application instructions: \(appTokens) tokens",
            "Package instructions and EBNF: \(packageTokens) tokens",
            "Static structure: \(structureTokens) tokens",
            "Base instructions: \(baseTokens) tokens",
            "Complete compact structural instructions without templates: \(expandedTokens) tokens",
            "Complete compact structural instructions: \(fullTokens) tokens",
            "Registered tools (include argument schemas): \(toolTokens) tokens",
            "Initial context component sum (estimate): \(total) tokens",
            "Structure delivery: \(fits ? "complete tree" : "not injected: exceeds context capacity"); static declarations; collection keys retrieved on demand."
        ]
        try Task.checkCancellation()
        if !fits {
            tokenDiagnostics = diagnostics
            throw StructuralContextError.structureTooLarge(tokens: total, capacity: model.contextSize)
        }
        return (full, diagnostics + ["Injected instructions: \(fullTokens) tokens"])
    }

    private enum StructuralContextError: LocalizedError {
        case structureTooLarge(tokens: Int, capacity: Int)
        var errorDescription: String? {
            switch self {
            case .structureTooLarge(let tokens, let capacity):
                "The complete structural instructions and read tools require approximately \(tokens) tokens; model context capacity is \(capacity). The structure was not truncated."
            }
        }
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
                var session = try await self.conversationSession(for: document)
                let prompt = question
                let model = SystemLanguageModel.default
                if let questionTokens = try? await model.tokenCount(for: question) {
                    guard self.generation == request, !Task.isCancelled else { return }
                    self.tokenDiagnostics.removeAll { $0.hasPrefix("Latest user question:") || $0.hasPrefix("Latest submitted prompt:") }
                    self.tokenDiagnostics.append("Latest user question: \(questionTokens) tokens")
                    self.tokenDiagnostics.append("Latest submitted prompt: \(questionTokens) tokens")
                }
                guard self.generation == request, !Task.isCancelled else { return }
                guard self.snapshot().map(DocumentVersion.init) == version else {
                    self.discardStaleDocument(version)
                    self.messages.append(.init(speaker: .error, text: "The document changed before the query. Ask again."))
                    return
                }
                let response: LanguageModelSession.Response<String>
                do {
                    response = try await session.respond(to: prompt)
                } catch LanguageModelError.contextSizeExceeded {
                    guard self.generation == request, !Task.isCancelled else { return }
                    guard self.snapshot().map(DocumentVersion.init) == version else {
                        self.discardStaleDocument(version)
                        self.messages.append(.init(speaker: .error, text: "The document changed during the query. Ask again to read the current values."))
                        return
                    }
                    // Only the last successful transcript is eligible for replay.
                    // The failed prompt and its partial tool activity are excluded.
                    let previous = self.completedTranscript ?? Transcript(entries: session.transcript.prefix(1))
                    let condensed = Self.condensedTranscript(previous)
                    self.completedTranscript = condensed
                    self.session = nil
                    session = try await self.conversationSession(for: document)
                    self.emit("session.rollover")
                    if let retryTokens = try? await model.tokenCount(for: prompt) {
                        guard self.generation == request, !Task.isCancelled else { return }
                        self.tokenDiagnostics.removeAll { $0.hasPrefix("Latest retry prompt:") }
                        self.tokenDiagnostics.append("Latest retry prompt: \(retryTokens) tokens")
                    }
                    // Exactly one retry. A second context error reaches the outer catch.
                    response = try await session.respond(to: prompt)
                }
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
                            "Model context exceeded (\(details.tokenCount) tokens; limit \(details.contextSize)). Instructions, tools, conversation and read results share this limit. The request still exceeds the limit after session recovery. Request a smaller result."))
                    } else {
                        self.messages.append(.init(speaker: .error, text: error.localizedDescription))
                    }
                }
            }
        }
    }

    /// Retain the original instructions and at most two complete prompt transactions.
    /// Keep all native entries between each prompt and its completed response.
    static func condensedTranscript(_ transcript: Transcript) -> Transcript {
        let entries = Array(transcript)
        var retained: [Transcript.Entry] = []
        if let first = entries.first, case .instructions = first { retained.append(first) }
        let starts = entries.indices.filter { index in
            if case .prompt = entries[index] { return true }
            return false
        }
        var completed: [ArraySlice<Transcript.Entry>] = []
        for (offset, start) in starts.enumerated() {
            let end = offset + 1 < starts.count ? starts[offset + 1] : entries.count
            let turn = entries[start..<end]
            if let last = turn.last, case .response = last { completed.append(turn) }
        }
        for turn in completed.suffix(2) { retained.append(contentsOf: turn) }
        return Transcript(entries: retained)
    }

    private func discardStaleDocument(_ version: DocumentVersion) {
        if snapshot()?.id != version.id { messages = [] }
        clearDocumentContext()
    }

    private func clearDocumentContext() {
        session = nil
        sessionDocument = nil
        preparationTask?.cancel()
        preparationTask = nil
        preparationID = nil
        structureContext = nil
        sessionInstructions = nil
        tokenDiagnostics = []
        completedTranscript = nil
        frameworkTranscript = nil
    }

    private func invalidateRequest() {
        generation += 1
        activeRequest?.cancel()
        activeRequest = nil
        preparationTask?.cancel()
        preparationTask = nil
        preparationID = nil
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
