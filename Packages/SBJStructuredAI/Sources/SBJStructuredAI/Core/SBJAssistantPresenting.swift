import Foundation
import SBJLocalization

/// A lightweight presentation boundary. Staged-change members are retained for existing hosts.
@MainActor
public protocol SBJAssistantPresenting: AnyObject {
	var availabilityState: SBJAssistantState { get }
	/// Optional backend name for availability messaging.
	var availabilityProviderName: String? { get }
	/// A backend can provide guidance specific to its current availability.
	func availabilityMessage(for state: SBJAssistantState) -> String?
	/// Session-local feedback and the context for a user correction.
	var feedback: SBJAssistantFeedback { get }
	var currentTurnID: UUID { get }
	var feedbackRevision: Int { get }
	var messages: [SBJAssistantMessage] { get }
	var pendingProposal: SBJStructuralChangeSummary? { get }
	var isResponding: Bool { get }
	var isPersisting: Bool { get }
	var isActive: Bool { get }
	var canSubmit: Bool { get }
	var canApprove: Bool { get }
	/// Framework tool calls, arguments, results and failures supplied by the host.
	/// May contain document values. Shown only when diagnostics are expanded.
	var frameworkDiagnostics: [String] { get }
	/// Optional raw backend transcript supplied by the host, for export.
	var frameworkTranscript: String? { get }
	/// Explicit local diagnostic action; never submits a model request.
	var canPrintInstructions: Bool { get }
	func printInstructions()

	func submit(_ text: String)
	func stop()
	func approve()
	func reject()
	/// Current structured reply choices; for example, ambiguity resolution.
	var shortcuts: [SBJAssistantShortcut] { get }
	/// Called for a shortcut; default behavior is equivalent to submitting its reply.
	func selectShortcut(_ shortcut: SBJAssistantShortcut)
	/// Hosts can customize errors without modifying the generic view.
	func displayError(_ message: String) -> String
}

public extension SBJAssistantPresenting {
	var availabilityProviderName: String? { nil }
	func availabilityMessage(for state: SBJAssistantState) -> String? { nil }
	var isPersisting: Bool { false }
	var frameworkDiagnostics: [String] { [] }
	var frameworkTranscript: String? { nil }
	var canPrintInstructions: Bool { false }
	func printInstructions() {}
	var shortcuts: [SBJAssistantShortcut] { [] }
	func selectShortcut(_ shortcut: SBJAssistantShortcut) { submit(shortcut.reply) }
	func displayError(_ message: String) -> String { message }

	/// Explicit export only; raw backend diagnostics may contain document values.
	var exportText: String {
		var lines: [String] = ["Assistant Conversation", ""]
		for message in messages {
			let speaker = message.speaker.nomenclature.title
			lines.append("\(speaker):\n\(message.text)\n")
		}
		if !frameworkDiagnostics.isEmpty {
			lines.append("\n--- Tool diagnostics ---\n")
			lines.append(contentsOf: frameworkDiagnostics)
		}
		if let transcript = frameworkTranscript {
			lines.append("\n--- Backend transcript ---\n")
			lines.append(transcript)
		}
		return lines.joined(separator: "\n")
	}
}
