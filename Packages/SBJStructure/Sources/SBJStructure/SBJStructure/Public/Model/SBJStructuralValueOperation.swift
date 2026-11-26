import Foundation
import SBJLocalization

/// Operations on a single, concrete Swift value. Collection mutations are modeled
/// separately by `SBJStructuralCollectionOperation`.
public enum SBJValueOperationKind: String, CaseIterable, Hashable, Sendable {
    case assign, toggle, increase, decrease, multiply, divide
    case appendText, prependText, removeText, replaceText
    case advanceDate
}

public enum SBJValueOperationNomenclature {
    public static func info(for kind: SBJValueOperationKind) -> SBJNomenclature {
        switch kind {
        case .assign: .init(title: "Set", summary: "Replace the value", aliases: ["assign"])
        case .toggle: .init(title: "Toggle", summary: "Invert a Boolean")
        case .increase: .init(title: "Increase", summary: "Add an amount to the current value", aliases: ["increment"])
        case .decrease: .init(title: "Decrease", summary: "Subtract an amount from the current value", aliases: ["decrement"])
        case .multiply: .init(title: "Multiply", summary: "Multiply the current value")
        case .divide: .init(title: "Divide", summary: "Divide the current value")
        case .appendText: .init(title: "Append Text", summary: "Add text at the end")
        case .prependText: .init(title: "Prepend Text", summary: "Add text at the beginning")
        case .removeText: .init(title: "Remove Text", summary: "Remove a literal substring")
        case .replaceText: .init(title: "Replace Text", summary: "Replace matching literal text")
        case .advanceDate: .init(title: "Shift Date", summary: "Shift a date by a time interval", aliases: ["postpone"])
        }
    }

    /// Language matching is type-qualified by the caller, since verbs such as
    /// "add" and "remove" can also indicate collection operations.
    public static func matching(_ term: String) -> [SBJValueOperationKind] {
        let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        return SBJValueOperationKind.allCases.filter { kind in
            let info = info(for: kind)
            return ([kind.rawValue] + (info.nonEmptyTitle.map { [$0] } ?? []) + info.aliases)
                .contains { $0.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        }
    }
}

/// Operands are actual typed values, not JSON text produced by a language model.
public enum SBJStructuralValueOperation {
    case assign(Any)
    case toggle
    case increase(Any)
    case decrease(Any)
    case multiply(Any)
    case divide(Any)
    case appendText(String)
    case prependText(String)
    case removeText(String)
    case replaceText(String, with: String)
    case advanceDate(TimeInterval)

    public var kind: SBJValueOperationKind {
        switch self {
        case .assign: .assign
        case .toggle: .toggle
        case .increase: .increase
        case .decrease: .decrease
        case .multiply: .multiply
        case .divide: .divide
        case .appendText: .appendText
        case .prependText: .prependText
        case .removeText: .removeText
        case .replaceText: .replaceText
        case .advanceDate: .advanceDate
        }
    }
}

public enum SBJStructuralValueOperationError: Error, LocalizedError, Equatable {
    case unsupportedOperation, typeMismatch, overflow, divisionByZero, nonfiniteValue, missingText

    public var errorDescription: String? {
        switch self {
        case .unsupportedOperation: "The operation is not supported for this field type."
        case .typeMismatch: "The operand does not match the field type."
        case .overflow: "The result is outside the numeric type's range."
        case .divisionByZero: "Cannot divide by zero."
        case .nonfiniteValue: "The operation would produce a nonfinite value."
        case .missingText: "The requested text is not present."
        }
    }
}

/// Implemented only by types with deterministic, checked transformations.
/// Field writeability and model constraints are checked by the mutation caller.
public protocol SBJStructuralValueNode {
    var sbjSupportedValueOperations: Set<SBJValueOperationKind> { get }
    func sbjApplyingValueOperation(_ operation: SBJStructuralValueOperation) throws -> Any
}

public enum SBJStructuralValueMutation {
    public static func supportedOperations(for value: Any) -> Set<SBJValueOperationKind> {
        (value as? any SBJStructuralValueNode)?.sbjSupportedValueOperations ?? []
    }

    public static func applying(_ operation: SBJStructuralValueOperation, to value: Any) throws -> Any {
        guard let node = value as? any SBJStructuralValueNode,
              node.sbjSupportedValueOperations.contains(operation.kind) else {
            throw SBJStructuralValueOperationError.unsupportedOperation
        }
        return try node.sbjApplyingValueOperation(operation)
    }
}

extension SBJStructuralValueNode where Self: FixedWidthInteger {
    public var sbjSupportedValueOperations: Set<SBJValueOperationKind> {
        [.assign, .increase, .decrease, .multiply, .divide]
    }

    public func sbjApplyingValueOperation(_ operation: SBJStructuralValueOperation) throws -> Any {
        switch operation {
        case .assign(let value):
            guard let value = value as? Self else { throw SBJStructuralValueOperationError.typeMismatch }
            return value
        case .increase(let value):
            guard let value = value as? Self else { throw SBJStructuralValueOperationError.typeMismatch }
            let result = addingReportingOverflow(value)
            guard !result.overflow else { throw SBJStructuralValueOperationError.overflow }
            return result.partialValue
        case .decrease(let value):
            guard let value = value as? Self else { throw SBJStructuralValueOperationError.typeMismatch }
            let result = subtractingReportingOverflow(value)
            guard !result.overflow else { throw SBJStructuralValueOperationError.overflow }
            return result.partialValue
        case .multiply(let value):
            guard let value = value as? Self else { throw SBJStructuralValueOperationError.typeMismatch }
            let result = multipliedReportingOverflow(by: value)
            guard !result.overflow else { throw SBJStructuralValueOperationError.overflow }
            return result.partialValue
        case .divide(let value):
            guard let value = value as? Self else { throw SBJStructuralValueOperationError.typeMismatch }
            guard value != 0 else { throw SBJStructuralValueOperationError.divisionByZero }
            let result = dividedReportingOverflow(by: value)
            guard !result.overflow else { throw SBJStructuralValueOperationError.overflow }
            return result.partialValue
        default: throw SBJStructuralValueOperationError.unsupportedOperation
        }
    }
}

extension Int: SBJStructuralValueNode {}
extension Int8: SBJStructuralValueNode {}
extension Int16: SBJStructuralValueNode {}
extension Int32: SBJStructuralValueNode {}
extension Int64: SBJStructuralValueNode {}
extension UInt: SBJStructuralValueNode {}
extension UInt8: SBJStructuralValueNode {}
extension UInt16: SBJStructuralValueNode {}
extension UInt32: SBJStructuralValueNode {}
extension UInt64: SBJStructuralValueNode {}

extension SBJStructuralValueNode where Self: BinaryFloatingPoint {
    public var sbjSupportedValueOperations: Set<SBJValueOperationKind> {
        [.assign, .increase, .decrease, .multiply, .divide]
    }

    public func sbjApplyingValueOperation(_ operation: SBJStructuralValueOperation) throws -> Any {
        let result: Self
        switch operation {
        case .assign(let value):
            guard let value = value as? Self else { throw SBJStructuralValueOperationError.typeMismatch }
            result = value
        case .increase(let value):
            guard let value = value as? Self else { throw SBJStructuralValueOperationError.typeMismatch }
            result = self + value
        case .decrease(let value):
            guard let value = value as? Self else { throw SBJStructuralValueOperationError.typeMismatch }
            result = self - value
        case .multiply(let value):
            guard let value = value as? Self else { throw SBJStructuralValueOperationError.typeMismatch }
            result = self * value
        case .divide(let value):
            guard let value = value as? Self else { throw SBJStructuralValueOperationError.typeMismatch }
            guard value != 0 else { throw SBJStructuralValueOperationError.divisionByZero }
            result = self / value
        default: throw SBJStructuralValueOperationError.unsupportedOperation
        }
        guard self.isFinite, result.isFinite else { throw SBJStructuralValueOperationError.nonfiniteValue }
        return result
    }
}

extension Float: SBJStructuralValueNode {}
extension Double: SBJStructuralValueNode {}
extension CGFloat: SBJStructuralValueNode {}

extension Bool: SBJStructuralValueNode {
    public var sbjSupportedValueOperations: Set<SBJValueOperationKind> { [.assign, .toggle] }
    public func sbjApplyingValueOperation(_ operation: SBJStructuralValueOperation) throws -> Any {
        switch operation {
        case .toggle: return !self
        case .assign(let value):
            guard let value = value as? Bool else { throw SBJStructuralValueOperationError.typeMismatch }
            return value
        default: throw SBJStructuralValueOperationError.unsupportedOperation
        }
    }
}

extension String: SBJStructuralValueNode {
    public var sbjSupportedValueOperations: Set<SBJValueOperationKind> {
        [.assign, .appendText, .prependText, .removeText, .replaceText]
    }
    public func sbjApplyingValueOperation(_ operation: SBJStructuralValueOperation) throws -> Any {
        switch operation {
        case .assign(let value):
            guard let value = value as? String else { throw SBJStructuralValueOperationError.typeMismatch }
            return value
        case .appendText(let text): return self + text
        case .prependText(let text): return text + self
        case .removeText(let text):
            guard !text.isEmpty, contains(text) else { throw SBJStructuralValueOperationError.missingText }
            return replacingOccurrences(of: text, with: "")
        case .replaceText(let old, let new):
            guard !old.isEmpty, contains(old) else { throw SBJStructuralValueOperationError.missingText }
            return replacingOccurrences(of: old, with: new)
        default: throw SBJStructuralValueOperationError.unsupportedOperation
        }
    }
}

extension Date: SBJStructuralValueNode {
    public var sbjSupportedValueOperations: Set<SBJValueOperationKind> { [.assign, .advanceDate] }
    public func sbjApplyingValueOperation(_ operation: SBJStructuralValueOperation) throws -> Any {
        switch operation {
        case .assign(let value):
            guard let value = value as? Date else { throw SBJStructuralValueOperationError.typeMismatch }
            guard value.timeIntervalSinceReferenceDate.isFinite else { throw SBJStructuralValueOperationError.nonfiniteValue }
            return value
        case .advanceDate(let seconds):
            guard seconds.isFinite else { throw SBJStructuralValueOperationError.nonfiniteValue }
            let shifted = addingTimeInterval(seconds)
            guard shifted.timeIntervalSinceReferenceDate.isFinite else { throw SBJStructuralValueOperationError.nonfiniteValue }
            return shifted
        default: throw SBJStructuralValueOperationError.unsupportedOperation
        }
    }
}
