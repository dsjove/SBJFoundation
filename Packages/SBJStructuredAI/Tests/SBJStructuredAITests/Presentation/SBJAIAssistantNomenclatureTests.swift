import Testing
import SBJLocalization
@testable import SBJStructuredAI

@Suite("AssistantNomenclatureTests")
struct AssistantNomenclatureTests {
@Test func assistantNomenclatureHasDistinctResolvableKeys() {
    let values = SBJAIAssistantNomenclature.all
    #expect(values.count == 35)
    #expect(values.values.allSatisfy { !$0.title.isEmpty })
    #expect(SBJAIAssistantNomenclature.send.title == "Send")
    #expect(SBJAIAssistantNomenclature.feedback.title == "Feedback")
    #expect(SBJAIAssistantNomenclature.shareTranscript.accessibilityLabel != nil)
}

#if canImport(FoundationModels) && canImport(SwiftUI) && !os(watchOS) && !os(tvOS)
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
@Test func eachAssistantMessageSpeakerHasNomenclature() {
    #expect(SBJAIAssistantMessage.Speaker.user.nomenclature.title == "You")
    #expect(SBJAIAssistantMessage.Speaker.assistant.nomenclature.title == "Assistant")
    #expect(SBJAIAssistantMessage.Speaker.error.nomenclature.title == "Error")
    #expect(SBJAIAssistantMessage.Speaker.diagnostic.nomenclature.title == "Discovery diagnostics")
}
#endif
}
