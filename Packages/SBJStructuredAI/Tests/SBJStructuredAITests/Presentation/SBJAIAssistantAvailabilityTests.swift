import Testing
@testable import SBJStructuredAI

@Suite("Assistant availability policy")
struct SBJAIAssistantAvailabilityTests {
    @Test("Unsupported hides the entry point and prohibits chat")
    func unsupported() {
        let state = SBJAIAssistantState.unsupported
        #expect(!state.isVisible)
        #expect(!state.canChat)
        #expect(!state.showsProgress)
    }

    @Test("Apple Intelligence disabled remains discoverable without chat")
    func disabled() {
        let state = SBJAIAssistantState.disabled
        #expect(state.isVisible)
        #expect(!state.canChat)
        #expect(!state.showsProgress)
    }

    @Test("Preparing remains discoverable with indeterminate progress")
    func preparing() {
        let state = SBJAIAssistantState.preparing
        #expect(state.isVisible)
        #expect(!state.canChat)
        #expect(state.showsProgress)
    }

    @Test("Ready permits chat; unknown remains discoverable without chat or progress")
    func otherStates() {
        #expect(SBJAIAssistantState.ready.isVisible)
        #expect(SBJAIAssistantState.ready.canChat)
        #expect(!SBJAIAssistantState.ready.showsProgress)
        #expect(SBJAIAssistantState.unknown.isVisible)
        #expect(!SBJAIAssistantState.unknown.canChat)
        #expect(!SBJAIAssistantState.unknown.showsProgress)
    }

    @Test(arguments: [SBJAIAssistantState.ready, .unsupported, .disabled, .preparing, .unknown])
    func prewarmPolicy(state: SBJAIAssistantState) {
        #expect(state.canPrewarm(hasSession: false, isResponding: false) == (state == .ready))
        #expect(!state.canPrewarm(hasSession: true, isResponding: false))
        #expect(!state.canPrewarm(hasSession: false, isResponding: true))
        #expect(!state.canPrewarm(hasSession: true, isResponding: true))
    }

    #if arch(x86_64) || !canImport(FoundationModels) || os(watchOS) || os(tvOS)
    @MainActor @Test("Unsupported runtime does not offer an Assistant")
    func unsupportedRuntime() {
        #expect(SBJAIAssistantAvailability.state == .unsupported)
        #expect(!SBJAIAssistantAvailability.isVisible)
    }
    #endif
}

#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import FoundationModels

@Suite("Apple Foundation Models availability mapping")
@MainActor
struct SBJAppleAvailabilityTests {
	@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func deviceNotEligible() {
        #expect(SBJAIAssistantAvailability.classify(.unavailable(.deviceNotEligible)) == .unsupported)
    }
	@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func appleIntelligenceNotEnabled() {
        #expect(SBJAIAssistantAvailability.classify(.unavailable(.appleIntelligenceNotEnabled)) == .disabled)
    }
	@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func modelNotReady() {
        #expect(SBJAIAssistantAvailability.classify(.unavailable(.modelNotReady)) == .preparing)
    }
	@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func available() {
        #expect(SBJAIAssistantAvailability.classify(.available) == .ready)
    }
}
#endif

#if canImport(SwiftUI) && !os(watchOS) && !os(tvOS)
import SwiftUI

@Suite("Availability view construction")
@MainActor
struct SBJAIAssistantAvailabilityViewTests {
	@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test(arguments: [SBJAIAssistantState.unsupported, .disabled, .preparing, .ready, .unknown])
    func buildsView(state: SBJAIAssistantState) {
        let view = SBJAIAssistantAvailabilityView(state: state)
        #expect(view.state == state)
        _ = view.body
    }
}
#endif
