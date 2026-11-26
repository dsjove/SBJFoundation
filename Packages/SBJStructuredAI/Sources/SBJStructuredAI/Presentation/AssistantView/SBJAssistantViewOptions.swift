import Foundation

/// Reusable presentation switches. A host can expose only the controls it wants.
public struct SBJAssistantViewOptions: Sendable, Equatable {
	public var hasSpeechToggle: Bool
	public var hasMicrophoneToggle: Bool
	public var hasDiagnostics: Bool
	public var hasShareDialog: Bool
	public var simpleCommands: Bool

	public init(
		hasSpeechToggle: Bool = false,
		hasMicrophoneToggle: Bool = false,
		hasDiagnostics: Bool = false,
		hasShareDialog: Bool = false,
		simpleCommands: Bool = true
	) {
#if canImport(Speech) && canImport(AVFoundation) && !os(watchOS) && !os(tvOS)
		self.hasSpeechToggle = hasSpeechToggle
		self.hasMicrophoneToggle = hasMicrophoneToggle
#else
		self.hasSpeechToggle = false
		self.hasMicrophoneToggle = false
#endif
		self.hasDiagnostics = hasDiagnostics
#if os(tvOS)
		self.hasShareDialog = false
#else
		self.hasShareDialog = hasShareDialog
#endif
		self.simpleCommands = simpleCommands
	}
}

