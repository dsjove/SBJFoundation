#if DEBUG && canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Foundation
import SBJStructure
import Testing
@testable import SBJStructuredAI

@SBJStructure
private struct SBJLiveQueryFixture {
    var scores: [String: Int] = ["Quartz": 7381]
    var doubled: Int { 14762 }
}

@Suite("Native structured query (opt-in)", .serialized)
@MainActor
struct SBJAIStructuredQueryLiveTests {
    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SBJ_RUN_LIVE_QUERY_TESTS"] == "1"))
    func readsCurrentDocument() async throws {
        try #require(SBJAIAvailability.state == .ready)
        let coordinator = SBJAIAssistantCoordinator<SBJLiveQueryFixture>(snapshot: {
            .init(id: "query-test", revision: 0, model: .init(), allowsEditing: false)
        })
        defer { coordinator.deactivate() }
        coordinator.activate()
        coordinator.submit("What is the score for Quartz in this document? Reply with digits only.")
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(90))
        while coordinator.isResponding && clock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        try #require(!coordinator.isResponding, "Native query timed out")
        try #require(coordinator.messages.last?.speaker == .assistant)
        #expect(coordinator.messages.last?.text.contains("7381") == true)
        #expect(coordinator.structureContext?.snapshot.paths.contains("$/scores/key:Quartz/value") == true)
        #expect(coordinator.frameworkTranscript?.contains("readStructure") == true)
    }
}
#endif
