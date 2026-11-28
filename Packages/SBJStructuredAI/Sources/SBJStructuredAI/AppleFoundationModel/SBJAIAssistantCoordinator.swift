#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Foundation
import FoundationModels
import Observation
import SBJStructure

/// Conversational boundary. Mutation transactions are independent of native tools.
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
    var pendingProposal: SBJStructuralChangeSummary? { transaction.summary }
    var isPersisting: Bool { transaction.isPersisting }
    private let supportsMutation: Bool
    private let transaction: SBJAssistantTransaction<Root>
    private(set) var isResponding = false
    private(set) var isActive = false
    private(set) var currentTurnID = UUID()
    /// Available for inspection without parsing the native session transcript.
    private(set) var structureContext: SBJSemanticReadSnapshot?
    var frameworkDiagnostics: [String] {
        guard let context = structureContext else { return [] }
        return [
            "Static structure: \(context.rootType), \(context.declarationCount) declarations, \(context.entries.count) snapshot nodes",
            "Complete compact structure: \(context.structuralDescription().utf8.count) UTF-8 bytes",
        ] + tokenDiagnostics
    }
    private(set) var frameworkTranscript: String?
    var canSubmit: Bool { isActive && !isResponding && !isPersisting && pendingProposal == nil && hasDocument && SBJAIAvailability.state == .ready }
    var canApprove: Bool { isActive && transaction.canApprove }
    var hasDocument: Bool { snapshot() != nil }
    var feedbackRevision: Int { snapshot()?.revision ?? -1 }

    private let snapshot: @MainActor () -> SBJAssistantDocument<Root>?
    private let diagnostic: (@MainActor (SBJAssistantDiagnostic, UUID, Int) -> Void)?
    private let errorDisplay: @MainActor (String) -> String
    var instructions: String {
        domainInstructions + "\n\n" + SBJAIInstructions.session + (supportsMutation && snapshot()?.allowsEditing == true ? "\n" + SBJAIInstructions.mutationInstructions : "")
    }
    private var tokenDiagnostics: [String] = []
    private let domainInstructions: String
    private let traversalOptions: SBJTraversalOptions
    private var session: LanguageModelSession?
    private var preparationTask: Task<Void, Error>?
    private var preparationID: UUID?
    private(set) var sessionInstructions: String?
    private var completedTranscript: Transcript?
    private var activeRequest: Task<Void, Never>?
    private var generation = 0
    // A native tool may suspend while the presentation reviews a proposal.
    // Scope the waiter and tool adapters to this request/session, not the model's text.
    @ObservationIgnored private var mutationWaiter: (id: UUID, continuation: CheckedContinuation<String, any Error>)?
    private var mutationAttempted = false
    private var mutationCommittedVersion: DocumentVersion?
    private var sessionToolID: UUID?
    private struct DocumentVersion: Equatable, Sendable {
        let id: String
        let revision: Int
        let allowsEditing: Bool
        init(_ document: SBJAssistantDocument<Root>) {
            id = document.id
            revision = document.revision
            allowsEditing = document.allowsEditing
        }
    }
    private var sessionDocument: DocumentVersion?

    /// Persistence is optional for read-only hosts.
    init(
        snapshot: @escaping @MainActor () -> SBJAssistantDocument<Root>?,
        persist: SBJAssistantTransaction<Root>.Persist? = nil,
        domainInstructions: String,
        traversalOptions: SBJTraversalOptions = .all,
        diagnostic: (@MainActor (SBJAssistantDiagnostic, UUID, Int) -> Void)? = nil,
        displayError: @escaping @MainActor (String) -> String = { $0 }
    ) {
        self.snapshot = snapshot
        self.supportsMutation = persist != nil && Root.self is any SBJMutableStructure.Type
        self.transaction = SBJAssistantTransaction(snapshot: snapshot, persist: persist)
        self.domainInstructions = domainInstructions
        self.traversalOptions = traversalOptions
        self.diagnostic = diagnostic
        self.errorDisplay = displayError
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

    func startNewSession() {
        guard isActive else { return }
        invalidateRequest()
        clearDocumentContext()
        messages.removeAll()
        currentTurnID = UUID()
        feedback.deleteAll()
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
        guard !isPersisting else { return }
        if transaction.synchronize() {
            let documentChanged = sessionDocument?.id != snapshot()?.id
            invalidateRequest()
            clearDocumentContext()
            if documentChanged { messages = [] }
            else { messages.append(.init(speaker: .error, text: "The document changed. Please request the edit again.")) }
            return
        }
        guard let previous = sessionDocument else { return }
        let current = snapshot().map(DocumentVersion.init)
        guard current != previous else { return }
        // The approved write is the only allowed version transition during a turn.
        if isResponding, let committed = mutationCommittedVersion, current == committed { return }
        let wasResponding = isResponding
        invalidateRequest()
        clearDocumentContext()
        if current?.id != previous.id {
            messages = []
        } else if wasResponding {
            messages.append(.init(speaker: .error, text: "The document changed during the query. Ask again to read the current values."))
        }
    }
    /// Common transaction entry point for deterministic mutation adapters.
    @discardableResult
    func stageMutation(document: SBJAssistantDocument<Root>, location: [String], replacement: Any,
                       changes: [SBJFieldChangeSummary]) throws -> SBJStructuralChangeSummary {
        guard isActive else { throw SBJAssistantTransaction<Root>.Failure.notWritable }
        return try transaction.stage(document: document, location: location, replacement: replacement, changes: changes)
    }

    /// Stage one checked edit and suspend the native tool until the user has
    /// reviewed it and (if approved) the host has confirmed persistence.
    func requestLeafMutation(document: SBJAssistantDocument<Root>, context: SBJSemanticReadSnapshot,
                             path: [String], value: String) async throws -> String {
        guard !mutationAttempted else { throw SBJLeafMutationError.resolution(SBJSemanticReadResult.error(SBJAIInstructions.duplicateMutation).promptText) }
        let proposal = try SBJLeafMutation.prepare(document.model, snapshot: context, keyPath: path, value: value)
        return try await requestMutation(document: document, proposal: proposal)
    }

    func requestCollectionMutation(document: SBJAssistantDocument<Root>, context: SBJSemanticReadSnapshot,
                                   request: SBJCollectionMutationRequest) async throws -> String {
        guard !mutationAttempted else { throw SBJLeafMutationError.resolution(SBJSemanticReadResult.error(SBJAIInstructions.duplicateMutation).promptText) }
        switch try SBJCollectionMutation.prepare(document.model, snapshot: context, request: request) {
        case .count(let count): return "value:\(count)"
        case .proposal(let proposal): return try await requestMutation(document: document, proposal: proposal)
        }
    }

    private func requestMutation(document: SBJAssistantDocument<Root>, proposal: SBJLeafMutation.Proposal) async throws -> String {
        let id = UUID()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                do {
                    _ = try stageMutation(document: document, location: proposal.location,
                                          replacement: proposal.replacement, changes: [proposal.change])
                    mutationAttempted = true
                    mutationWaiter = (id, continuation)
                } catch { continuation.resume(throwing: error) }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in self?.cancelMutationWaiter(id: id) }
        }
    }

    private func finishMutation(_ result: Result<String, any Error>) {
        guard let waiter = mutationWaiter else { return }
        mutationWaiter = nil
        waiter.continuation.resume(with: result)
    }

    private func cancelMutationWaiter(id: UUID) {
        guard mutationWaiter?.id == id else { return }
        transaction.discardPending()
        finishMutation(.failure(CancellationError()))
    }

    func approve() {
        guard canApprove, pendingProposal != nil else { return }
        let request = generation
        let documentID = snapshot()?.id
        transaction.approve { [weak self] outcome in
            guard let self, self.isActive, self.generation == request else { return }
            guard self.snapshot()?.id == documentID else {
                self.finishMutation(.failure(SBJAssistantTransaction<Root>.Failure.staleProposal))
                return
            }
            switch outcome {
            case .applied:
                self.mutationCommittedVersion = self.snapshot().map(DocumentVersion.init)
                self.emit("proposal.applied")
                self.messages.append(.init(speaker: .assistant, text: "Changes applied."))
                self.finishMutation(.success(SBJAIInstructions.mutationApplied))
                if !self.isResponding { self.clearDocumentContext() }
            case .failed(let error):
                self.emit("proposal.approvalFailed")
                self.messages.append(.init(speaker: .error, text: error.localizedDescription))
                self.finishMutation(.failure(error))
            case .rejected: break
            }
        }
    }
    func reject() {
        guard isActive, transaction.reject() != nil else { return }
        emit("proposal.rejected")
        messages.append(.init(speaker: .assistant, text: "Proposed changes cancelled."))
        finishMutation(.success(SBJAIInstructions.mutationRejected))
    }

    /// Prepare the exact session that will handle the next request. Safe before
    /// activation and during a conversation; unavailable, busy, or already-created
    /// sessions are left alone. This is a best-effort hint, not a readiness guarantee.
    func prewarm() {
        guard SBJAIAvailability.state == .ready, !isResponding, !isPersisting, pendingProposal == nil else { return }
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
            structureContext = try SBJSemanticReadSnapshot(instance: document.model, traversalOptions: traversalOptions)
            sessionDocument = version
        }
        if session != nil { return nil }
        if let preparationTask { return preparationTask }
        guard let context = structureContext else { throw SBJSemanticReadError.noDocument }
        let toolID = UUID()
        sessionToolID = toolID
        let tools = sessionTools(context, document: document, id: toolID)
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

    /// Single registration list for initial sessions and transcript recovery.
    static func readTools(snapshot: SBJSemanticReadSnapshot,
                          isCurrent: (@MainActor @Sendable () -> Bool)? = nil) -> [any Tool] {
        [SBJAIReadValueTool(snapshot: snapshot, isCurrent: isCurrent),
         SBJAIReadKeysTool(snapshot: snapshot, isCurrent: isCurrent),
         SBJAIReadDescriptionTool(snapshot: snapshot, isCurrent: isCurrent)]
    }

    /// Inspect native definitions rather than parsing the transcript's debug text.
    static func nativeToolNames(in transcript: Transcript) -> [String] {
        for entry in transcript {
            if case .instructions(let instructions) = entry {
                return instructions.toolDefinitions.map(\.name)
            }
        }
        return []
    }

    private func sessionTools(_ context: SBJSemanticReadSnapshot, document: SBJAssistantDocument<Root>, id: UUID) -> [any Tool] {
        let version = DocumentVersion(document)
        let current: @MainActor @Sendable () -> Bool = { [weak self] in
            guard let self else { return false }
            return self.sessionToolID == id && self.isActive && self.isResponding && !self.mutationAttempted &&
                self.snapshot().map(DocumentVersion.init) == version
        }
        var tools = Self.readTools(snapshot: context, isCurrent: current)
        if supportsMutation && document.allowsEditing {
            tools.append(SBJAIMutateValueTool { [weak self] path, value in
                guard let self, current(), !Task.isCancelled else {
                    return SBJSemanticReadResult.error(SBJAIInstructions.staleToolResult).promptText
                }
                return try await self.requestLeafMutation(document: document, context: context, path: path, value: value)
            })
            tools.append(SBJAIMutateCollectionTool { [weak self] request in
                guard let self, current(), !Task.isCancelled else {
                    return SBJSemanticReadResult.error(SBJAIInstructions.staleToolResult).promptText
                }
                return try await self.requestCollectionMutation(document: document, context: context, request: request)
            })
        }
        return tools
    }

    private func expectedToolNames(for document: SBJAssistantDocument<Root>) -> [String] {
        let reads = [SBJAIInstructions.readValueName, SBJAIInstructions.readKeysName, SBJAIInstructions.readDescriptionName]
        return supportsMutation && document.allowsEditing ? reads + [SBJAIInstructions.mutateValueName, SBJAIInstructions.mutateCollectionName] : reads
    }

    private func installSession(tools: [any Tool], text: String) {
        let next = completedTranscript.map { LanguageModelSession(tools: tools, transcript: $0) }
            ?? LanguageModelSession(tools: tools, instructions: text)
        session = next
        recordNativeToolDiagnostics(next.transcript, expected: tools.map(\.name))
        next.prewarm()
    }

    private func recordNativeToolDiagnostics(_ transcript: Transcript, expected: [String]) {
        let native = Self.nativeToolNames(in: transcript)
        tokenDiagnostics.removeAll { $0.hasPrefix("Native transcript tools:") || $0.hasPrefix("Tool registration mismatch:") }
        tokenDiagnostics.append("Native transcript tools: " + (native.isEmpty ? "(none reported)" : native.joined(separator: ", ")))
        if Set(expected) != Set(native) {
            tokenDiagnostics.append("Tool registration mismatch: expected " + expected.joined(separator: ", "))
        }
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
                context = try SBJSemanticReadSnapshot(instance: document.model, traversalOptions: traversalOptions)
            }
            let text = completeInstructions(context)
            messages.append(.init(speaker: .diagnostic, text: text))
        } catch {
            messages.append(.init(speaker: .diagnostic, text: error.localizedDescription))
        }
    }

    private func completeInstructions(_ context: SBJSemanticReadSnapshot, usesTemplates: Bool = true) -> String {
        instructions + "\n\n" + SBJAIInstructions.structureHeading + context.structuralDescription(usesTemplates: usesTemplates)
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
        let packageText = SBJAIInstructions.session + (tools.contains { $0.name == SBJAIInstructions.mutateValueName } ? "\n" + SBJAIInstructions.mutationInstructions : "")
        let packageTokens = try await model.tokenCount(for: Instructions { packageText })
        let structure = SBJAIInstructions.structureHeading + context.structuralDescription(usesTemplates: true)
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
            "Configured tools: \(tools.map(\.name).joined(separator: ", "))",
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
        case mutationTurnExceeded
        var errorDescription: String? {
            switch self {
            case .mutationTurnExceeded: "The model ran out of context after a mutation request. The review outcome is shown in the conversation; the request was not replayed."
            case .structureTooLarge(let tokens, let capacity):
                "The complete structural instructions and registered tools require approximately \(tokens) tokens; model context capacity is \(capacity). The structure was not truncated."
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
        mutationAttempted = false
        mutationCommittedVersion = nil
        generation += 1
        let request = generation
        currentTurnID = UUID()
        isResponding = true
        messages.append(.init(speaker: .user, text: question))
        activeRequest = Task { [weak self] in
            guard let self, self.generation == request, !Task.isCancelled else { return }
            var failedTranscript: String?
            var latestSession: LanguageModelSession?
            defer {
                if self.generation == request {
                    self.transaction.discardPending()
                    self.finishMutation(.failure(CancellationError()))
                    self.isResponding = false
                    self.activeRequest = nil
                    let latest = latestSession.map { String(describing: $0.transcript) } ?? self.completedTranscript.map { String(describing: $0) }
                    let transcripts = [failedTranscript.map { "Before recovery:\n" + $0 }, latest.map { failedTranscript == nil ? $0 : "After recovery:\n" + $0 }].compactMap { $0 }
                    // A committed mutation must never leave a session backed by the old snapshot.
                    if self.mutationCommittedVersion != nil { self.clearDocumentContext() }
                    self.mutationCommittedVersion = nil
                    self.frameworkTranscript = transcripts.isEmpty ? nil : transcripts.joined(separator: "\n\n")
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
                latestSession = session
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
                    // Never replay a turn that has already staged a mutation.
                    if self.mutationAttempted { throw StructuralContextError.mutationTurnExceeded }
                    guard self.generation == request, !Task.isCancelled else { return }
                    guard self.snapshot().map(DocumentVersion.init) == version else {
                        self.discardStaleDocument(version)
                        self.messages.append(.init(speaker: .error, text: "The document changed during the query. Ask again to read the current values."))
                        return
                    }
                    failedTranscript = String(describing: session.transcript)
                    // Only the last successful transcript is eligible for replay.
                    // The failed prompt and its partial tool activity are excluded.
                    let previous = self.completedTranscript ?? Transcript(entries: session.transcript.prefix(1))
                    let condensed = Self.condensedTranscript(previous)
                    self.completedTranscript = condensed
                    self.session = nil
                    latestSession = nil
                    session = try await self.conversationSession(for: document)
                    latestSession = session
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
                guard self.snapshot().map(DocumentVersion.init) == (self.mutationCommittedVersion ?? version) else {
                    self.discardStaleDocument(version)
                    self.messages.append(.init(speaker: .error, text: "The document changed during the query. Ask again to read the current values."))
                    return
                }
                self.completedTranscript = session.transcript
                self.recordNativeToolDiagnostics(session.transcript, expected: self.expectedToolNames(for: document))
                self.messages.append(.init(speaker: .assistant, text: response.content))
            } catch {
                guard self.generation == request, !Task.isCancelled else { return }
                self.session = nil
                if self.snapshot().map(DocumentVersion.init) != (self.mutationCommittedVersion ?? version) {
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
        sessionToolID = nil
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
        transaction.discardPending()
        finishMutation(.failure(CancellationError()))
        mutationAttempted = false
        mutationCommittedVersion = nil
        sessionToolID = nil
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
        guard isResponding || pendingProposal != nil else { return }
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
