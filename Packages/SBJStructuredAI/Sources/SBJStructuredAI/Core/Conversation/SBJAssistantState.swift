import Foundation

/// UI policy is independent of Apple hardware and can be tested on any platform.
public enum SBJAssistantState: Equatable, Sendable {
	case ready
	case unsupported
	case disabled
	case preparing
	case unknown

	public var isVisible: Bool { self != .unsupported }
	public var canChat: Bool { self == .ready }
	public var showsProgress: Bool { self == .preparing }

	/// Internal policy: prewarm only when a new idle session can be retained.
	func canPrewarm(hasSession: Bool, isResponding: Bool) -> Bool {
		self == .ready && !hasSession && !isResponding
	}
}

