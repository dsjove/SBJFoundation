#if DEBUG && canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Foundation
import Testing
@testable import SBJStructuredAI

@Suite("Native conversation continuity (opt-in)", .serialized)
@MainActor
struct SBJAIConversationContinuityLiveTests {
    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SBJ_RUN_LIVE_CONTINUITY_TESTS"] == "1"))
    func remembersEarlierTurn() async throws {
        try #require(SBJAIAvailability.state == .ready)
        let coordinator = SBJAIAssistantCoordinator<Int>(snapshot: {
            .init(id: "test", revision: 0, model: 0, allowsEditing: false)
        }, domainInstructions: "Test document.")
        defer { coordinator.deactivate() }
        coordinator.activate()
        #expect(coordinator.messages.isEmpty)
        coordinator.prewarm() // Repeated hint must not replace the warmed session.
        coordinator.submit("For this conversation, my favorite color is cobalt. Acknowledge this fact.")
        try await waitForResponse(coordinator)
        coordinator.submit("What favorite color did I tell you? Reply with just the color.")
        try await waitForResponse(coordinator)
        #expect(coordinator.messages.count == 4)
        #expect(coordinator.messages.last?.speaker == .assistant)
        #expect(coordinator.messages.last?.text.localizedCaseInsensitiveContains("cobalt") == true)
        coordinator.deactivate()
        coordinator.activate()
        #expect(coordinator.messages.isEmpty)
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    private func waitForResponse(_ coordinator: SBJAIAssistantCoordinator<Int>) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(90))
        while coordinator.isResponding && clock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        try #require(!coordinator.isResponding, "Native response timed out")
        try #require(coordinator.messages.last?.speaker == .assistant)
    }
}
#endif
