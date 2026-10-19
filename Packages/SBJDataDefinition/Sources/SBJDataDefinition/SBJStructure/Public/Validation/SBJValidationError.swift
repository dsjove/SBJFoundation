import Foundation

/// Standard validation failure used by generated and custom invariants.
///
/// Validation errors are snapshots. When a failing value is available its
/// presentation description is captured with the error so diagnostics do not
/// lose the value that caused the failure.
public struct SBJValidationError: LocalizedError, @unchecked Sendable {
    public let keyPath: SBJValidationKeyPath
    public let message: String
    public let valueDescription: String?

    public init(_ message: String, at keyPath: SBJValidationKeyPath) {
        self.message = message
        self.keyPath = keyPath
        self.valueDescription = nil
    }

    public init<Value>(_ value: Value, at keyPath: SBJValidationKeyPath, _ message: String) {
        self.message = message
        self.keyPath = keyPath
        self.valueDescription = Self.describe(value)
    }

    public init<Root, Value>(_ message: String, at keyPath: KeyPath<Root, Value>) {
        self.init(message, at: SBJValidationKeyPath(keyPath))
    }

    public init<Root, Value>(_ value: Value, at keyPath: KeyPath<Root, Value>, _ message: String) {
        self.init(value, at: SBJValidationKeyPath(keyPath), message)
    }

    public var errorDescription: String? { message }

    private static func describe<Value>(_ value: Value) -> String? {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional, mirror.children.isEmpty {
            return "nil"
        }
        return SBJValueDescription.describe(value)
    }
}
