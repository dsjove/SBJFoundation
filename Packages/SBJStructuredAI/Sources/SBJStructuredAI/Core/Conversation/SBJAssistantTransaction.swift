import Foundation
import Observation
import SBJLocalization
import SBJStructure

/// Backend-independent proposal lifecycle, adapted from the former SBJAIProposalDocument.
/// The host must supply value-semantic document snapshots and atomically check the
/// expected ID/revision when persisting. No live model is changed during staging.
@MainActor
@Observable
final class SBJAssistantTransaction<Root> {
    typealias Persist = @MainActor (Root, String, Int, @escaping @MainActor (Result<Void, Error>) -> Void) -> Void
    enum Failure: LocalizedError {
        case notWritable, busy, staleProposal, noChange, unsupportedRoot, invalidProposal
        var errorDescription: String? {
            switch self {
            case .notWritable: "This document cannot be edited."
            case .busy: "Review the pending change or wait for saving to finish."
            case .staleProposal: "The document changed after the proposal was prepared."
            case .noChange: "That would not change anything."
            case .unsupportedRoot: "This model does not support structural mutation."
            case .invalidProposal: "The proposal is no longer available."
            }
        }
    }
    enum Outcome { case applied, rejected, failed(Error) }
    private struct Pending {
        let original: SBJAssistantDocument<Root>
        let candidate: Root
        let summary: SBJStructuralChangeSummary
    }
    private var pending: Pending?
    private var persistenceID: UUID?
    private let snapshot: @MainActor () -> SBJAssistantDocument<Root>?
    private let persist: Persist?
    var summary: SBJStructuralChangeSummary? { pending?.summary }
    var isPersisting: Bool { persistenceID != nil }
    var canApprove: Bool {
        guard let pending, let current = snapshot(), current.allowsEditing else { return false }
        return !isPersisting && matches(current, pending.original)
    }

    init(snapshot: @escaping @MainActor () -> SBJAssistantDocument<Root>?, persist: Persist?) {
        self.snapshot = snapshot
        self.persist = persist
    }

    private func matches(_ current: SBJAssistantDocument<Root>, _ original: SBJAssistantDocument<Root>) -> Bool {
        current.id == original.id && current.revision == original.revision &&
            SBJStructuralCompare.equals(current.model, original.model)
    }

    /// Location and replacement must come from deterministic resolution/conversion,
    /// never directly from a model-generated path. The receipt is built by the tool.
    @discardableResult
    func stage(document: SBJAssistantDocument<Root>, location: [String], replacement: Any,
               changes: [SBJFieldChangeSummary]) throws -> SBJStructuralChangeSummary {
        guard pending == nil, !isPersisting else { throw Failure.busy }
        guard persist != nil, let current = snapshot(), current.allowsEditing, document.allowsEditing else {
            throw Failure.notWritable
        }
        guard current.model is any SBJMutableStructure,
              Mirror(reflecting: current.model).displayStyle != .class else { throw Failure.unsupportedRoot }
        guard matches(current, document) else { throw Failure.staleProposal }
        guard !location.isEmpty, !changes.isEmpty else { throw Failure.invalidProposal }
        let candidate = try SBJStructuralMutation.replacing(current.model, at: location[...], with: replacement)
        try SBJInvariantCheck.validate(candidate, at: .root)
        guard !SBJStructuralCompare.equals(current.model, candidate) else { throw Failure.noChange }
        let summary = SBJStructuralChangeSummary(id: UUID().uuidString, changes: changes)
        pending = Pending(original: current, candidate: candidate, summary: summary)
        return summary
    }

    func discardPending() { pending = nil }

    /// Returns true if a staged proposal was invalidated by a host change.
    @discardableResult
    func synchronize() -> Bool {
        guard let pending else { return false }
        if let current = snapshot(), current.allowsEditing, matches(current, pending.original) { return false }
        discardPending()
        return true
    }

    func reject() -> Outcome? {
        guard pending != nil else { return nil }
        discardPending()
        return .rejected
    }

    func approve(completion: @escaping @MainActor (Outcome) -> Void) {
        guard let draft = pending, !isPersisting else { return }
        discardPending()
        guard let persist, let current = snapshot(), current.allowsEditing else {
            completion(.failed(Failure.notWritable)); return
        }
        guard matches(current, draft.original) else {
            completion(.failed(Failure.staleProposal)); return
        }
        do { try SBJInvariantCheck.validate(draft.candidate, at: .root) }
        catch { completion(.failed(error)); return }
        let id = UUID()
        persistenceID = id
        persist(draft.candidate, current.id, current.revision) { [weak self] result in
            guard let self, self.persistenceID == id else { return }
            self.persistenceID = nil
            switch result {
            case .success: completion(.applied)
            case .failure(let error): completion(.failed(error))
            }
        }
    }
}
