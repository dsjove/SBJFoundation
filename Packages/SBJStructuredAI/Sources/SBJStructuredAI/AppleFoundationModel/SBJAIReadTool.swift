#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Foundation
import FoundationModels

/// A native Foundation Models tool with compact dynamically generated parameters.
/// It validates paths against immutable instance data and has no persistence,
/// mutation, external I/O or host callbacks.
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct SBJAIReadTool: Tool {
    let name = "readStructure"
    let description = "Find fields and collection members, describe metadata, read values, list children or count entries. Read-only."
    let parameters: GenerationSchema
    private let snapshot: SBJSemanticReadSnapshot

    init(context: SBJAIStructureContext) {
        parameters = context.readParameters
        snapshot = context.snapshot
    }

    @concurrent
    func call(arguments: GeneratedContent) async throws -> GeneratedContent {
        try Task.checkCancellation()
        let output: GeneratedContent
        do {
            let raw = try arguments.value(String.self, forProperty: "operation")
            if raw == "find" {
                let query = try arguments.value(String.self, forProperty: "query")
                output = snapshot.find(query).nativeContent
            } else if let operation = SBJSemanticReadOperation(rawValue: raw) {
                let paths = try arguments.value([String].self, forProperty: "paths")
                guard paths.count <= 6 else {
                    return .init(properties: ["error": "Select at most six paths."])
                }
                let offset = (try? arguments.value(Int.self, forProperty: "offset")) ?? 0
                if operation == .children {
                    guard paths.count == 1 else {
                        return .init(properties: ["error": "List children of one path at a time."])
                    }
                    output = try snapshot.query(.children, paths: paths, childrenOffset: offset,
                                                childrenLimit: 12).nativeContent
                } else {
                    output = try snapshot.query(operation, paths: paths).nativeContent
                }
            } else {
                output = .init(properties: ["error": "Unknown operation. Use find, read, children, count or describe."])
            }
        } catch {
            // A bad read is recoverable; the model may select a different path.
            // Return an error as data rather than fail the whole conversation.
            output = .init(properties: ["error": error.localizedDescription])
        }
        try Task.checkCancellation()
        let model = SystemLanguageModel.default
        // Direct tool tests need no model availability. For a live model use its
        // own tokenizer, not byte estimates, to avoid returning large subtrees.
        if model.isAvailable,
           let tokens = try? await model.tokenCount(for: output),
           tokens > max(1, model.contextSize / 4) {
            return .init(properties: ["error": "Result has \(tokens) tokens. Use count, find, or children and read fewer/smaller fields."])
        }
        try Task.checkCancellation()
        return output
    }
}
#endif
