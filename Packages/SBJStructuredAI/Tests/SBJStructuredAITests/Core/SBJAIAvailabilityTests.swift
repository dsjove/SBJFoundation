import Testing
@testable import SBJStructuredAI

#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import FoundationModels

@Suite("Apple Foundation Models availability mapping")
@MainActor
struct SBJAIAvailabilityTests {
    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func deviceNotEligible() {
        #expect(SBJAIAvailability.classify(.unavailable(.deviceNotEligible)) == .unsupported)
    }
    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func appleIntelligenceNotEnabled() {
        #expect(SBJAIAvailability.classify(.unavailable(.appleIntelligenceNotEnabled)) == .disabled)
    }
    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func modelNotReady() {
        #expect(SBJAIAvailability.classify(.unavailable(.modelNotReady)) == .preparing)
    }
    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func available() {
        #expect(SBJAIAvailability.classify(.available) == .ready)
    }
}
#endif


#if arch(x86_64) || !canImport(FoundationModels) || os(watchOS) || os(tvOS)
@Suite("Unsupported backend runtime")
struct SBJAIUnsupportedRuntimeTests {
    @MainActor @Test("Unsupported runtime does not offer an Assistant")
    func unsupportedRuntime() {
        #expect(SBJAIAvailability.state == .unsupported)
        #expect(!SBJAIAvailability.isVisible)
        let assistant = SBJAIAvailability.makeAssistant(snapshot: { nil as SBJAssistantDocument<Int>? })
        #expect(assistant == nil)
    }
}
#endif
