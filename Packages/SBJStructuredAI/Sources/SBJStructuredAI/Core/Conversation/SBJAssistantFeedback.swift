import Foundation
import Observation

/// Generic, privacy-preserving classification of an Assistant lifecycle event.
///
/// WHY: The coordinator owns the meaning of its event codes. Host applications
/// should choose whether/how to store feedback, not parse internal string codes
/// to infer the proposal phase or failure category. No document text is included.
public struct SBJAssistantDiagnostic: Sendable, Equatable, Codable {
	public enum Category: String, Codable, CaseIterable, Sendable {
		case wrongField, wrongIntent, wrongValue, policyDenied, invariantFailure
		case constructionFailure, toolFailure, staleProposal, cancelled
		case userCorrection, userRejectedProposal
	}
	public enum Phase: String, Codable, Sendable {
		case resolution, reporting, proposal, approval, commit, presentation
	}
	public enum Outcome: String, Codable, Sendable {
		case succeeded, failed, corrected, rejected, cancelled
	}

	public let code: String
	public let category: Category
	public let phase: Phase
	public let outcome: Outcome

	/// Classify a standard coordinator event once, at its origin.
	/// Unknown codes remain reportable as tool/reporting failures.
	public init(code: String) {
		self.code = code
		switch code {
		case "request.stopped":
			category = .cancelled; phase = .presentation; outcome = .cancelled
		case "proposal.rejected":
			category = .userRejectedProposal; phase = .proposal; outcome = .rejected
		case "proposal.stale":
			category = .staleProposal; phase = .approval; outcome = .failed
		case "proposal.approvalFailed":
			category = .invariantFailure; phase = .approval; outcome = .failed
		default:
			category = .toolFailure; phase = .reporting; outcome = .failed
		}
	}

	public init(
		code: String,
		category: Category,
		phase: Phase,
		outcome: Outcome
	) {
		self.code = code
		self.category = category
		self.phase = phase
		self.outcome = outcome
	}
}

/// A sanitized, reusable feedback record. The host decides whether to present,
/// retain, or export these records; this type intentionally contains no prompt,
/// generated response, model value, document identifier, or audio.
public struct SBJAssistantFeedbackEvent: Codable, Identifiable, Equatable, Sendable {
	public typealias Category = SBJAssistantDiagnostic.Category
	public typealias Phase = SBJAssistantDiagnostic.Phase
	public typealias Outcome = SBJAssistantDiagnostic.Outcome

	public let schemaVersion: Int
	public let id: UUID
	public let timestamp: Date
	public let turnID: UUID
	public let documentRevision: Int
	public let diagnostic: SBJAssistantDiagnostic

	public init(
		id: UUID = UUID(),
		timestamp: Date = Date(),
		turnID: UUID,
		documentRevision: Int,
		diagnostic: SBJAssistantDiagnostic
	) {
		self.schemaVersion = 1
		self.id = id
		self.timestamp = timestamp
		self.turnID = turnID
		self.documentRevision = documentRevision
		self.diagnostic = diagnostic
	}

	public init(
		id: UUID = UUID(),
		timestamp: Date = Date(),
		turnID: UUID,
		documentRevision: Int,
		category: Category,
		phase: Phase,
		outcome: Outcome,
		diagnosticCode: String
	) {
		self.init(
			id: id,
			timestamp: timestamp,
			turnID: turnID,
			documentRevision: documentRevision,
			diagnostic: .init(
				code: diagnosticCode,
				category: category,
				phase: phase, outcome:
				outcome))
	}
}

/// Generic, explicitly opt-in session-local feedback. The assistant owns the
/// event vocabulary; the host merely chooses presentation and collection policy.
/// Disabling collection also clears retained events to minimize exposure.
@MainActor
@Observable
public final class SBJAssistantFeedback {
	public var isEnabled = false {
		didSet { if !isEnabled { events.removeAll() } }
	}
	public private(set) var events: [SBJAssistantFeedbackEvent] = []

	public init() {}

	public func record(event: SBJAssistantDiagnostic, turnID: UUID, revision: Int) {
		guard isEnabled else { return }
		events.append(.init(turnID: turnID, documentRevision: revision, diagnostic: event))
	}

	public func recordCorrection(turnID: UUID, revision: Int,
								 category: SBJAssistantDiagnostic.Category) {
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
