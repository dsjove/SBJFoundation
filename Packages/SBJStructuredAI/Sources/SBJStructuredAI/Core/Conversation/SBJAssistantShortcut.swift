import Foundation

/// A deterministic reply shortcut shown in the conversation. The ID is stable
/// within the host's current choice set. The host decides what the selection means.
public struct SBJAssistantShortcut: Identifiable, Sendable, Equatable {
	public let id: String
	public let title: String
	public let reply: String

	public init(id: String, title: String, reply: String) {
		self.id = id
		self.title = title
		self.reply = reply
	}
}
