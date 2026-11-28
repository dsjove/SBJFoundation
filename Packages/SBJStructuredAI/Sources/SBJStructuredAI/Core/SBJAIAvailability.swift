import Foundation
import SBJStructure
#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import FoundationModels
#endif

@MainActor
public enum SBJAIAvailability {
	public static var isVisible: Bool { state.isVisible }

	/// Create an assistant for a supported SDK/runtime without exposing its concrete type.
	/// Disabled or preparing Apple Intelligence is still a valid presentation state.
	/// Returns nil when the native backend cannot run on this OS/architecture.
	/// Construction does not load a model, read the snapshot, or start a conversation.
	public static func makeAssistant<Root>(
		snapshot: @escaping @MainActor () -> SBJAssistantDocument<Root>?,
		persist: (@MainActor (Root, String, Int, @escaping @MainActor (Result<Void, Error>) -> Void) -> Void)? = nil,
		domainInstructions: String,
        traversalOptions: SBJTraversalOptions = .all,
		diagnostic: (@MainActor (SBJAssistantDiagnostic, UUID, Int) -> Void)? = nil,
		displayError: @escaping @MainActor (String) -> String = { $0 }
	) -> (any SBJAssistantCoordinating & SBJAssistantPresenting)? {
		#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS) && !arch(x86_64)
		if #available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *) {
			return SBJAIAssistantCoordinator(
				snapshot: snapshot, persist: persist, domainInstructions: domainInstructions, traversalOptions: traversalOptions,
				diagnostic: diagnostic, displayError: displayError
			)
		}
		#endif
		return nil
	}

	public static var state: SBJAssistantState {
		#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS) && !arch(x86_64)
		if #available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *) {
			return classify(SystemLanguageModel.default.availability)
		}
		#endif
		return .unsupported
	}

	/// Provider-specific guidance is owned by the Apple adapter, not the views.
	public static func message(for state: SBJAssistantState) -> String? {
		switch state {
		case .disabled:
			"Enable Apple Intelligence in Settings (System Settings on Mac) to use the Assistant."
		case .preparing:
			"The language model is not ready. It may be downloading or updating. The Assistant will become available when the model is ready."
		default:
			nil
		}
	}

	#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
	@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
	public static func classify(_ availability: SystemLanguageModel.Availability) -> SBJAssistantState {
		switch availability {
		case .available: return .ready
		case .unavailable(let reason):
			switch reason {
			case .deviceNotEligible: return .unsupported
			case .appleIntelligenceNotEnabled: return .disabled
			case .modelNotReady: return .preparing
			@unknown default: return .unknown
			}
		@unknown default: return .unknown
		}
	}
	#endif
}
