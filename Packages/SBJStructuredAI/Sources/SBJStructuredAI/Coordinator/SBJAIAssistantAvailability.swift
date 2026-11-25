import Foundation
#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import FoundationModels
#endif

/// UI policy is independent of Apple hardware and can be tested on any platform.
public enum SBJAIAssistantState: Equatable, Sendable {
    case ready, unsupported, disabled, preparing, unknown

    public var isVisible: Bool { self != .unsupported }
    public var canChat: Bool { self == .ready }
    public var showsProgress: Bool { self == .preparing }

    /// Internal policy: prewarm only when a new idle session can be retained.
    func canPrewarm(hasSession: Bool, isResponding: Bool) -> Bool {
        self == .ready && !hasSession && !isResponding
    }
}

@MainActor
public enum SBJAIAssistantAvailability {
    public static var isVisible: Bool { state.isVisible }

    public static var state: SBJAIAssistantState {
        #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS) && !arch(x86_64)
        if #available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *) {
            return classify(SystemLanguageModel.default.availability)
        }
        #endif
        return .unsupported
    }

    #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    public static func classify(_ availability: SystemLanguageModel.Availability) -> SBJAIAssistantState {
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
