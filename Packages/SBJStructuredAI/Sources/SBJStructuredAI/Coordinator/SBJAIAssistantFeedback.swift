#if canImport(FoundationModels) && canImport(SwiftUI) && !os(watchOS) && !os(tvOS)
import Foundation
import Observation

/// A sanitized, reusable feedback record. The host decides whether to present,
/// retain, or export these records; this type intentionally contains no prompt,
/// generated response, model value, document identifier, or audio.
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
public struct SBJAIAssistantFeedbackEvent: Codable, Identifiable, Equatable, Sendable {
    public typealias Category = SBJAIAssistantDiagnostic.Category
    public typealias Phase = SBJAIAssistantDiagnostic.Phase
    public typealias Outcome = SBJAIAssistantDiagnostic.Outcome

    public let schemaVersion: Int
    public let id: UUID
    public let timestamp: Date
    public let turnID: UUID
    public let documentRevision: Int
    public let category: Category
    public let phase: Phase
    public let outcome: Outcome
    public let diagnosticCode: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), turnID: UUID,
                documentRevision: Int, diagnostic: SBJAIAssistantDiagnostic) {
        self.schemaVersion = 1
        self.id = id
        self.timestamp = timestamp
        self.turnID = turnID
        self.documentRevision = documentRevision
        self.category = diagnostic.category
        self.phase = diagnostic.phase
        self.outcome = diagnostic.outcome
        self.diagnosticCode = diagnostic.code
    }

    public init(id: UUID = UUID(), timestamp: Date = Date(), turnID: UUID,
                documentRevision: Int, category: Category, phase: Phase,
                outcome: Outcome, diagnosticCode: String) {
        self.schemaVersion = 1
        self.id = id
        self.timestamp = timestamp
        self.turnID = turnID
        self.documentRevision = documentRevision
        self.category = category
        self.phase = phase
        self.outcome = outcome
        self.diagnosticCode = diagnosticCode
    }
}

/// Generic, explicitly opt-in session-local feedback. The assistant owns the
/// event vocabulary; the host merely chooses presentation and collection policy.
/// Disabling collection also clears retained events to minimize exposure.
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
@MainActor
@Observable
public final class SBJAIAssistantFeedback {
    public var isEnabled = false {
        didSet { if !isEnabled { events.removeAll() } }
    }
    public private(set) var events: [SBJAIAssistantFeedbackEvent] = []

    public init() {}

    public func record(event: SBJAIAssistantDiagnostic, turnID: UUID, revision: Int) {
        guard isEnabled else { return }
        events.append(.init(turnID: turnID, documentRevision: revision, diagnostic: event))
    }

    public func recordCorrection(turnID: UUID, revision: Int,
                                 category: SBJAIAssistantDiagnostic.Category) {
        guard isEnabled else { return }
        switch category {
        case .wrongField, .wrongIntent, .wrongValue, .userCorrection:
            events.append(.init(turnID: turnID, documentRevision: revision,
                                category: category, phase: .resolution,
                                outcome: .corrected,
                                diagnosticCode: "user.reportedCorrection"))
        default:
            return
        }
    }

    public func deleteAll() { events.removeAll() }

    /// Explicit user-initiated export only; never transmitted automatically.
    public var exportJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(events) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }
}
#endif
