import Foundation

/// A type that can create a context-free default instance of itself.
///
/// Use this for model types whose default construction is not represented by
/// ``SBJStructured/sbjDefaultValue()``. `@SBJStructure` uses it for associated-
/// value enums, where construction may require recursively creating the values
/// belonging to a case.
public protocol SBJDefaultValueCreatable {
    static func sbjCreateDefaultValueIfPossible() -> Self?
}

/// Context-free default-value creation for SBJStructure models and common value
/// types.
///
/// This API is deliberately independent of SwiftUI and the editor. It can be
/// used by importers, command-line tools, tests, alternate editors, collection
/// builders, and any other consumer that needs the same default construction
/// semantics.
///
/// Application-specific creation belongs outside this type. For example,
/// ``SBJEditorRegistry`` first checks its registered creators and only then
/// falls back to this context-free factory.
public enum SBJDefaultValue {
    public static func value<T>(for type: T.Type) -> T? {
        // Intentional built-in defaults for Swift/Foundation primitives. Custom
        // SBJ/application types provide construction through
        // `SBJDefaultValueCreatable` or `SBJStructured.sbjDefaultValue()`.
        switch type {
        case is String.Type: return "" as? T
        case is Int.Type: return 0 as? T
        case is Int8.Type: return Int8(0) as? T
        case is Int16.Type: return Int16(0) as? T
        case is Int32.Type: return Int32(0) as? T
        case is Int64.Type: return Int64(0) as? T
        case is UInt.Type: return UInt(0) as? T
        case is UInt8.Type: return UInt8(0) as? T
        case is UInt16.Type: return UInt16(0) as? T
        case is UInt32.Type: return UInt32(0) as? T
        case is UInt64.Type: return UInt64(0) as? T
        case is Double.Type: return 0.0 as? T
        case is Float.Type: return Float(0) as? T
        case is CGFloat.Type: return CGFloat(0) as? T
        case is Decimal.Type: return Decimal(0) as? T
        case is Bool.Type: return false as? T
        case is Date.Type: return Date() as? T
        case is URL.Type: return URL(string: "https://") as? T
        case is UUID.Type: return UUID() as? T
        case is Data.Type: return Data() as? T
        default: break
        }

        if let creatable = T.self as? any SBJDefaultValueCreatable.Type {
            return creatable.sbjCreateDefaultValueIfPossible() as? T
        }
        if let structured = T.self as? any SBJStructured.Type,
           let value = structured.sbjDefaultValue() as? T {
            return value
        }
        if let caseIterable = T.self as? any CaseIterable.Type {
            return caseIterable.allCases.first(where: { _ in true }) as? T
        }
        return nil
    }
}
