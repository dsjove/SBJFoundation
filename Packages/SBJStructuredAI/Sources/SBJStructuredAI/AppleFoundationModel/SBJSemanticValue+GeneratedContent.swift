#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Foundation
import FoundationModels

/// Bridge typed snapshot values directly to Apple's tool output representation.
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
extension SBJSemanticValue {
    public var nativeContent: GeneratedContent {
        switch self {
        case .null: return .init(kind: .null)
        case .bool(let value): return .init(kind: .bool(value))
        case .signed(let value):
            if let exact = Double(exactly: value) { return .init(kind: .number(exact)) }
            return .init(kind: .string(String(value)))
        case .unsigned(let value):
            if let exact = Double(exactly: value) { return .init(kind: .number(exact)) }
            return .init(kind: .string(String(value)))
        case .number(let value):
            return value.isFinite ? .init(kind: .number(value)) : .init(kind: .string(String(value)))
        case .decimal(let value): return .init(kind: .string(NSDecimalNumber(decimal: value).stringValue))
        case .text(let value): return .init(kind: .string(value))
        case .array(let values):
            return .init(kind: .array(values.map(\.nativeContent)))
        case .object(let values):
            return .init(kind: .structure(properties: values.mapValues(\.nativeContent), orderedKeys: values.keys.sorted()))
        }
    }
}
#endif
