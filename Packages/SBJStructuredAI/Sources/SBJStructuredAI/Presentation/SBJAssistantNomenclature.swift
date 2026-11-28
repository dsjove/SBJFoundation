import SBJLocalization

/// Reusable Assistant presentation terminology, independent of any host document.
/// Stable keys follow the same SBJNomenclatureSet pattern as other SBJFoundation editors.
/// App-specific UI localization and overrides are intentionally deferred.
public enum SBJAssistantNomenclature: SBJNomenclatureSet {
	public static let all: [String: SBJNomenclature] = [
		"emptyTitle": .init(title: "Ask the Assistant", summary: "Chat with the assistant.", symbol: .system("sparkles")),
		"emptyDescription": .init(title: "Ask a question to start the conversation.", summary: "Chat with the assistant."),
		"prompt": .init(title: "Message"),
		"newSession": .init(title: "Reset Assistant", symbol: .system("trash.fill")),
		"resetConfirmationTitle": .init(title: "Reset AI Assistant?"),
		"resetConfirmationMessage": .init(title: "This will discard the current conversation, draft, diagnostics and any unapproved changes. Changes already applied to your document will not be affected."),
		"send": .init(title: "Send", symbol: .system("arrow.up.circle.fill")),
		"stop": .init(title: "Stop"),
		"approveTitle": .init(title: "Review proposed changes", symbol: .system("checkmark.shield")),
		"approve": .init(title: "Apply"),
		"reject": .init(title: "Cancel"),
		"resolvedField": .init(title: "Field"),
		"currentValue": .init(title: "Current"),
		"proposedValue": .init(title: "Proposed"),
		"readOnly": .init(title: "This document is read-only."),
		"speakResponses": .init(title: "Speak responses"),
		"shareSubject": .init(title: "Assistant conversation"),
		"shareMessage": .init(title: "Conversation and diagnostics exported from SBJStructuredAI"),
		"shareTranscript": .init(title: "Share transcript", symbol: .system("square.and.arrow.up"), accessibilityLabel: "Share conversation and diagnostics"),
		"printInstructions": .init(title: "Print Instructions"),
		"backendDiagnostics": .init(title: "Assistant diagnostics", symbol: .system("stethoscope")),
		"thinking": .init(title: "Thinking…"),
		"stopDictation": .init(title: "Stop dictation", symbol: .system("stop.circle.fill")),
		"startDictation": .init(title: "Start dictation", symbol: .system("mic")),
		"speakerUser": .init(title: "You"),
		"speakerAssistant": .init(title: "Assistant"),
		"speakerError": .init(title: "Error"),
		"speakerDiagnostic": .init(title: "Discovery diagnostics"),
		"feedback": .init(title: "Feedback"),
		"feedbackTitle": .init(title: "Assistant Feedback"),
		"collectDiagnostics": .init(title: "Collect anonymous Assistant diagnostics"),
		"privacyDescription": .init(title: "Diagnostics remain in memory during this Assistant session. They contain categories and codes, not prompts, document values, responses, or audio."),
		"exportDiagnostics": .init(title: "Export diagnostics", symbol: .system("square.and.arrow.up")),
		"deleteDiagnostics": .init(title: "Delete all diagnostics"),
		"reportMistake": .init(title: "Report an Assistant mistake"),
		"wrongField": .init(title: "Wrong field"),
		"wrongIntent": .init(title: "Misunderstood request"),
		"wrongValue": .init(title: "Wrong value"),
		"done": .init(title: "Done"),
	]
}
