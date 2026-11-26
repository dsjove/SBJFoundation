import Foundation
import Testing
import SBJStructuredAI

@Suite("Public assistant factory")
@MainActor
struct SBJAssistantFactoryTests {
    @Test func factoryRespectsRuntimeAvailability() throws {
        var reads = 0
        let assistant = SBJAIAvailability.makeAssistant(snapshot: {
            reads += 1
            return nil as SBJAssistantDocument<Int>?
        }, domainInstructions: "Test document.")
        #expect(reads == 0)
        #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS) && !arch(x86_64)
        if #available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *) {
            let instance = try #require(assistant)
            #expect(!instance.isActive)
            #expect(!instance.isResponding)
            #expect(instance.messages.isEmpty)
            return
        }
        #endif
        #expect(assistant == nil)
    }

    #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS) && !arch(x86_64)
    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func hostLifecycleAndFeedbackUseOnlyPublicProtocols() throws {
        var document: SBJAssistantDocument<Int>? = .init(id: "test", revision: 3, model: 42, allowsEditing: false)
        let result = SBJAIAvailability.makeAssistant(snapshot: { document }, domainInstructions: "Test document.", displayError: { "Host: " + $0 })
        let assistant = try #require(result)
        #expect(assistant.hasDocument)
        #expect(assistant.feedbackRevision == 3)
        #expect(assistant.displayError("error") == "Host: error")
        assistant.feedback.isEnabled = true
        assistant.activate()
        #expect(assistant.isActive)
        document = nil
        assistant.synchronize()
        #expect(!assistant.hasDocument)
        #expect(assistant.feedbackRevision == -1)
        assistant.submit("Read")
        #expect(assistant.messages.isEmpty)
        assistant.deactivate()
        #expect(!assistant.isActive)
    }
    #endif
}
