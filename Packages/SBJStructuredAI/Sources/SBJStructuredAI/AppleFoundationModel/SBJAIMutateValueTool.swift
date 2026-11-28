#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Foundation
import FoundationModels

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct SBJAIMutateValueTool: Tool {
    let name = SBJAIInstructions.mutateValueName
    let description = SBJAIInstructions.mutateValueDescription
    let includesSchemaInInstructions = true
    let propose: @MainActor @Sendable ([String], String) async throws -> String

    @Generable
    struct Arguments: Sendable {
        @Guide(description: SBJAIInstructions.valuePathGuide)
        let keyPath: [String]
        @Guide(description: SBJAIInstructions.mutationValueGuide)
        let value: String
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        try Task.checkCancellation()
        do { return try await propose(arguments.keyPath, arguments.value) }
        catch SBJLeafMutationError.resolution(let result) { return result }
        catch is CancellationError { throw CancellationError() }
        catch { return SBJSemanticReadResult.error(error.localizedDescription).promptText }
    }
}
#endif
