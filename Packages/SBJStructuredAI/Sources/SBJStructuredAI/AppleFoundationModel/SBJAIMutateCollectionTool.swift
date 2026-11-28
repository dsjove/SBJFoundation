#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Foundation
import FoundationModels

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct SBJAIMutateCollectionTool: Tool {
    let name = SBJAIInstructions.mutateCollectionName
    let description = SBJAIInstructions.mutateCollectionDescription
    let includesSchemaInInstructions = true
    let propose: @MainActor @Sendable (SBJCollectionMutationRequest) async throws -> String

    @Generable
    struct Arguments: Sendable {
        @Guide(description: SBJAIInstructions.collectionPathGuide)
        let keyPath: [String]
        @Guide(description: SBJAIInstructions.collectionOperationGuide)
        let operation: String
        @Guide(description: SBJAIInstructions.collectionMemberGuide)
        let member: String?
        @Guide(description: SBJAIInstructions.collectionPositionGuide)
        let position: Int?
        @Guide(description: SBJAIInstructions.collectionValueGuide)
        let value: String?
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        try Task.checkCancellation()
        do {
            return try await propose(.init(keyPath: arguments.keyPath, operation: arguments.operation,
                                           member: arguments.member, position: arguments.position, value: arguments.value))
        } catch SBJLeafMutationError.resolution(let result) { return result }
        catch is CancellationError { throw CancellationError() }
        catch { return SBJSemanticReadResult.error(error.localizedDescription).promptText }
    }
}
#endif
