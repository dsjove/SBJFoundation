#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Foundation

/// Generic, privacy-preserving classification of an Assistant lifecycle event.
///
/// WHY: The coordinator owns the meaning of its event codes. Host applications
/// should choose whether/how to store feedback, not parse internal string codes
/// to infer the proposal phase or failure category. No document text is included.
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
public struct SBJAIAssistantDiagnostic: Sendable, Equatable {
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
}
#endif
