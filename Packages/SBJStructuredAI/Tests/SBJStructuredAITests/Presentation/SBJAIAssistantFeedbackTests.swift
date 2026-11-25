import Foundation
import Testing
@testable import SBJStructuredAI

#if canImport(FoundationModels) && canImport(SwiftUI) && !os(watchOS) && !os(tvOS)
@Suite("AssistantFeedbackTests")
struct AssistantFeedbackTests {
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
@MainActor
@Test func feedbackIsOptInAndClearedOnDisable() {
    let feedback = SBJAIAssistantFeedback()
    let turn = UUID()
    feedback.record(event: .init(code: "request.stopped"), turnID: turn, revision: 4)
    #expect(feedback.events.isEmpty)

    feedback.isEnabled = true
    feedback.record(event: .init(code: "request.stopped"), turnID: turn, revision: 4)
    #expect(feedback.events.count == 1)
    #expect(feedback.events[0].category == .cancelled)
    #expect(feedback.events[0].phase == .presentation)
    #expect(feedback.events[0].outcome == .cancelled)
    #expect(feedback.events[0].documentRevision == 4)

    feedback.isEnabled = false
    #expect(feedback.events.isEmpty)
    #expect((try? JSONSerialization.jsonObject(with: Data(feedback.exportJSON.utf8)) as? [Any])?.isEmpty == true)
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
@MainActor
@Test func onlyCorrectionCategoriesBecomeUserCorrections() throws {
    let feedback = SBJAIAssistantFeedback()
    feedback.isEnabled = true
    let turn = UUID()
    feedback.recordCorrection(turnID: turn, revision: 2, category: .toolFailure)
    #expect(feedback.events.isEmpty)
    feedback.recordCorrection(turnID: turn, revision: 2, category: .wrongField)
    #expect(feedback.events.count == 1)
    #expect(feedback.events[0].outcome == .corrected)
    let data = try #require(feedback.exportJSON.data(using: .utf8))
    let decoded = try JSONDecoder.withISO8601Dates.decode([SBJAIAssistantFeedbackEvent].self, from: data)
    #expect(decoded.count == 1)
    #expect(decoded[0].turnID == turn)
}

}
private extension JSONDecoder {
    static var withISO8601Dates: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
#endif
