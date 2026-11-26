import Foundation
import Testing
@testable import SBJStructuredAI

@Suite("SBJAssistantFeedbackTests")
struct SBJAssistantFeedbackTests {
    @MainActor
    @Test func feedbackIsOptInAndClearedOnDisable() {
        let feedback = SBJAssistantFeedback()
        let turn = UUID()
        feedback.record(event: .init(code: "request.stopped"), turnID: turn, revision: 4)
        #expect(feedback.events.isEmpty)

        feedback.isEnabled = true
        feedback.record(event: .init(code: "request.stopped"), turnID: turn, revision: 4)
        #expect(feedback.events.count == 1)
        #expect(feedback.events[0].diagnostic.category == .cancelled)
        #expect(feedback.events[0].diagnostic.phase == .presentation)
        #expect(feedback.events[0].diagnostic.outcome == .cancelled)
        #expect(feedback.events[0].documentRevision == 4)

        feedback.isEnabled = false
        #expect(feedback.events.isEmpty)
        #expect((try? JSONSerialization.jsonObject(with: Data(feedback.exportJSON.utf8)) as? [Any])?.isEmpty == true)
    }

    @MainActor
    @Test func onlyCorrectionCategoriesBecomeUserCorrections() throws {
        let feedback = SBJAssistantFeedback()
        feedback.isEnabled = true
        let turn = UUID()
        feedback.recordCorrection(turnID: turn, revision: 2, category: .toolFailure)
        #expect(feedback.events.isEmpty)
        feedback.recordCorrection(turnID: turn, revision: 2, category: .wrongField)
        #expect(feedback.events.count == 1)
        #expect(feedback.events[0].diagnostic.outcome == .corrected)
        let data = try #require(feedback.exportJSON.data(using: .utf8))
        let decoded = try JSONDecoder.withISO8601Dates.decode([SBJAssistantFeedbackEvent].self, from: data)
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
