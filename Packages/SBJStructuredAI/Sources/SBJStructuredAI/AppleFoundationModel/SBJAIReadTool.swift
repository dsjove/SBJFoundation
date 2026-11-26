#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Foundation
import FoundationModels

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct SBJAIReadValueTool: Tool {
    let name = "readValue"
    let description = "Read a requested document value. Not for greetings or conversation."
    let snapshot: SBJSemanticReadSnapshot

    @Generable
    struct Arguments: Sendable {
        @Guide(description: "Path from root: only numeric field IDs as strings, exact collection keys, or @n array positions. Never include field labels.")
        let keyPath: [String]

    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        try await SBJAIReadExecutor(snapshot: snapshot).execute(.read, keyPath: arguments.keyPath)
    }
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct SBJAIReadKeysTool: Tool {
    let name = "readKeys"
    let description = "List current member keys of a requested collection, not its values."
    let snapshot: SBJSemanticReadSnapshot

    @Generable
    struct Arguments: Sendable {
        @Guide(description: "Path to collection: numeric field IDs and any ancestor member keys.")
        let keyPath: [String]
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        try await SBJAIReadExecutor(snapshot: snapshot).execute(.keys, keyPath: arguments.keyPath)
    }
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct SBJAIReadDescriptionTool: Tool {
    let name = "readDescription"
    let description = "Read the meaning, constraints and choices of a field at a key path, not its current value."
    let snapshot: SBJSemanticReadSnapshot

    @Generable
    struct Arguments: Sendable {
        @Guide(description: "Path from root: only numeric field IDs as strings, exact collection keys, or @n array positions. Never include field labels.")
        let keyPath: [String]
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        try await SBJAIReadExecutor(snapshot: snapshot).execute(.describe, keyPath: arguments.keyPath)
    }
}

/// Common validation and bounded EBNF text output, independent of argument generation.
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
private struct SBJAIReadExecutor: Sendable {
    let snapshot: SBJSemanticReadSnapshot

    @concurrent
    func execute(_ operation: SBJSemanticReadOperation, keyPath: [String]) async throws -> String {
        try Task.checkCancellation()
        do {
            let result = try snapshot.modelQuery(operation, stringKeyPath: keyPath).promptText
            let model = SystemLanguageModel.default
            let tokens: Int?
            if model.isAvailable {
                do { tokens = try await model.tokenCount(for: result) }
                catch is CancellationError { throw CancellationError() }
                catch { tokens = nil }
            } else { tokens = nil }
            try Task.checkCancellation()
            if let tokens, tokens > max(1, min(384, model.contextSize / 10)) {
                return SBJSemanticReadResult.error("Result too large. Select a more specific field.").promptText
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
