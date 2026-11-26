import Foundation
import SBJLocalization

/// A display-only conversation message. The reusable coordinator owns message
/// retention; this value does not carry a document model reference.
public struct SBJAssistantMessage: Identifiable, Equatable, Sendable {
	public enum Speaker: Sendable, Equatable { case user, assistant, error, diagnostic }

	public let id: UUID
	public let speaker: Speaker
	public let text: String

	public init(id: UUID = UUID(), speaker: Speaker, text: String) {
		self.id = id
		self.speaker = speaker
		self.text = text
	}
}

/// Each message kind owns its presentation nomenclature, as in other SBJFoundation models.
public extension SBJAssistantMessage.Speaker {
	var nomenclature: SBJNomenclature {
		switch self {
		case .user: SBJAssistantNomenclature.speakerUser
		case .assistant: SBJAssistantNomenclature.speakerAssistant
		case .error: SBJAssistantNomenclature.speakerError
		case .diagnostic: SBJAssistantNomenclature.speakerDiagnostic
		}
	}
}
