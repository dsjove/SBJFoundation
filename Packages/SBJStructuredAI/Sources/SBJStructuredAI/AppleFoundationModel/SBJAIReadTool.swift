#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Foundation
import FoundationModels

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct SBJAIReadValueTool: Tool {
    let name = SBJAIInstructions.readValueName
    let description = SBJAIInstructions.readValueDescription
    let snapshot: SBJSemanticReadSnapshot
    let includesSchemaInInstructions = true
    var isCurrent: (@MainActor @Sendable () -> Bool)? = nil

    @Generable
    struct Arguments: Sendable {
        @Guide(description: SBJAIInstructions.valuePathGuide)
        let keyPath: [String]

    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        try await SBJAIReadExecutor(snapshot: snapshot, isCurrent: isCurrent).execute(.read, keyPath: arguments.keyPath)
    }
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct SBJAIReadKeysTool: Tool {
    let name = SBJAIInstructions.readKeysName
    let description = SBJAIInstructions.readKeysDescription
    let snapshot: SBJSemanticReadSnapshot
    let includesSchemaInInstructions = true
    var isCurrent: (@MainActor @Sendable () -> Bool)? = nil

    @Generable
    struct Arguments: Sendable {
        @Guide(description: SBJAIInstructions.collectionPathGuide)
        let keyPath: [String]
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        try await SBJAIReadExecutor(snapshot: snapshot, isCurrent: isCurrent).execute(.keys, keyPath: arguments.keyPath)
    }
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct SBJAIReadDescriptionTool: Tool {
    let name = SBJAIInstructions.readDescriptionName
    let description = SBJAIInstructions.readDescriptionDescription
    let snapshot: SBJSemanticReadSnapshot
    let includesSchemaInInstructions = true
    var isCurrent: (@MainActor @Sendable () -> Bool)? = nil

    @Generable
    struct Arguments: Sendable {
        @Guide(description: SBJAIInstructions.descriptionPathGuide)
        let keyPath: [String]
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        try await SBJAIReadExecutor(snapshot: snapshot, isCurrent: isCurrent).execute(.describe, keyPath: arguments.keyPath)
    }
}

/// Common validation and bounded EBNF text output, independent of argument generation.
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
private struct SBJAIReadExecutor: Sendable {
    let snapshot: SBJSemanticReadSnapshot
    let isCurrent: (@MainActor @Sendable () -> Bool)?

    @concurrent
    func execute(_ operation: SBJSemanticReadOperation, keyPath: [String]) async throws -> String {
        try Task.checkCancellation()
        do {
            if let isCurrent, !(await isCurrent()) { return SBJSemanticReadResult.error(SBJAIInstructions.staleToolResult).promptText }
            let result = try snapshot.modelQuery(operation, stringKeyPath: keyPath).promptText
            let model = SystemLanguageModel.default
            let tokens: Int?
            if model.isAvailable {
                do { tokens = try await model.tokenCount(for: result) }
                catch is CancellationError { throw CancellationError() }
                catch { tokens = nil }
            } else { tokens = nil }
            try Task.checkCancellation()
            if let isCurrent, !(await isCurrent()) { return SBJSemanticReadResult.error(SBJAIInstructions.staleToolResult).promptText }
            if let tokens, tokens > max(1, min(384, model.contextSize / 10)) {
                return SBJSemanticReadResult.error(SBJAIInstructions.resultTooLarge).promptText
            }
            return result
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return SBJSemanticReadResult.error(error.localizedDescription).promptText
        }
    }
}
#endif
