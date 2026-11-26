/// Host application lifecycle contract, independent of the assistant backend.
/// Compose with `SBJAssistantPresenting` when a host also presents a conversation.
@MainActor
public protocol SBJAssistantCoordinating: AnyObject {
	var hasDocument: Bool { get }

	/// Start or resume the host's assistant presentation lifecycle.
	func activate()
	/// End the active presentation and cancel any outstanding work.
	func deactivate()
	/// Invalidate stale document context after a host document change.
	func synchronize()
	/// Optionally prepare the backend without starting a conversation.
	func prewarm()
}
