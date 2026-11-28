#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Foundation
import FoundationModels
import SBJStructure
import Testing
@testable import SBJStructuredAI

@Suite("Native key-path read tools")
struct SBJAIReadToolTests {
    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test @MainActor func registersAllReadTools() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        let tools = SBJAIAssistantCoordinator<Int>.readTools(snapshot: snapshot)
        let expected = ["readValue", "readKeys", "readDescription"]
        #expect(tools.map(\.name) == expected)
        #expect(tools.allSatisfy { $0.includesSchemaInInstructions })
        guard SystemLanguageModel.default.isAvailable else { return }
        let session = LanguageModelSession(tools: tools, instructions: "Test document.")
        #expect(Set(SBJAIAssistantCoordinator<Int>.nativeToolNames(in: session.transcript)) == Set(expected))
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func nativeToolReadsExactPath() async throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        let level = try #require(snapshot.declarationIdentifier(for: [.field("level")]))
        let tool = SBJAIReadValueTool(snapshot: snapshot)
        #expect(tool.name == SBJAIInstructions.readValueName)
        #expect(tool.description == SBJAIInstructions.readValueDescription)
        #expect(SBJAIReadKeysTool(snapshot: snapshot).name == SBJAIInstructions.readKeysName)
        #expect(SBJAIReadKeysTool(snapshot: snapshot).description == SBJAIInstructions.readKeysDescription)
        #expect(SBJAIReadDescriptionTool(snapshot: snapshot).description == SBJAIInstructions.readDescriptionDescription)
        let result = try await tool.call(arguments: .init(keyPath: [String(level)]))
        #expect(result == "value:9")
        let metadata = try await SBJAIReadDescriptionTool(snapshot: snapshot).call(arguments: .init(keyPath: [String(level)]))
        #expect(metadata.contains(#""title"="Experience level""#))
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func invalidCollectionPath() async throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        let items = try #require(snapshot.declarationIdentifier(for: [.field("items")]))
        let tool = SBJAIReadValueTool(snapshot: snapshot)
        let invalid = try await tool.call(arguments: .init(keyPath: [String(items), "@0"]))
        #expect(invalid == "memberRequired:replace:2;keys:@1=Same,@2=Same")
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func nativeKeyDiscoveryAndNegotiation() async throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        let items = String(try #require(snapshot.declarationIdentifier(for: [.field("items")])))
        let rank = String(try #require(snapshot.declarationIdentifier(for: [.field("items"), .member, .field("rank")])))
        let result = try await SBJAIReadKeysTool(snapshot: snapshot).call(arguments: .init(keyPath: [items]))
        #expect(result == "keys:@1=Same,@2=Same")
        let tool = SBJAIReadValueTool(snapshot: snapshot)
        let incomplete = try await tool.call(arguments: .init(keyPath: [items, rank]))
        #expect(incomplete == "memberRequired:insert:2;keys:@1=Same,@2=Same")
        let resolved = try await tool.call(arguments: .init(keyPath: [items, "@2", rank]))
        #expect(resolved == "value:8")
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func nativeMixedKeyPaths() async throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        let items = try #require(snapshot.declarationIdentifier(for: [.field("items")]))
        let rank = try #require(snapshot.declarationIdentifier(for: [.field("items"), .member, .field("rank")]))
        let tool = SBJAIReadValueTool(snapshot: snapshot)
        let second = try await tool.call(arguments: .init(keyPath: [String(items), "@2", String(rank)]))
        #expect(second == "value:8")
        let tags = try #require(snapshot.declarationIdentifier(for: [.field("tags")]))
        let named = try await tool.call(arguments: .init(keyPath: [String(tags), "North"]))
        #expect(named == #"value:"North""#)
        let description = try await SBJAIReadDescriptionTool(snapshot: snapshot).call(arguments: .init(keyPath: [String(items), "@1", String(rank)]))
        #expect(description.contains(#""type"="Int""#))
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func metadataForAbsentField() async throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        let parent = try #require(snapshot.declarationIdentifier(for: [.field("absent")]))
        let field = try #require(snapshot.declarationIdentifier(for: [.field("absent"), .field("neverInstantiatedField")]))
        let result = try await SBJAIReadDescriptionTool(snapshot: snapshot).call(arguments: .init(keyPath: [String(parent), String(field)]))
        #expect(result.contains("Describes the type even when its instance is absent."))
    }


}
#endif
