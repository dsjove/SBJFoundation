import Foundation
import CoreGraphics

/// Runtime validation helpers used by macro-generated and handwritten invariants.
///
/// Nothing in this type is invoked by ordinary property reads or writes. A
/// consumer must explicitly request validation, normally through `invariant`.
public enum SBJInvariantCheck {
    public static func validate<T>(_ value: T, at keyPath: SBJValidationKeyPath) throws {
        if let checkable = value as? any HasContentCheckable {
            try checkable.invariant(at: keyPath)
        }
    }

    /// Validates an annotated array while snapshotting each element's configured
    /// presentation title into the validation path.
    public static func validate<Element>(
        _ value: [Element],
        at keyPath: SBJValidationKeyPath,
        itemTitleKey: String
    ) throws {
        for (index, element) in value.enumerated() {
            guard let checkable = element as? any HasContentCheckable else { continue }
            let title = SBJCollectionItemIdentification.configuredTitle(
                for: element,
                itemTitleKey: itemTitleKey
            )
            try checkable.invariant(at: keyPath.appending(index: index, title: title))
        }
    }

    /// Validates an annotated set while snapshotting each member's configured
    /// presentation title into the validation path.
    public static func validate<Element: Hashable>(
        _ value: Set<Element>,
        at keyPath: SBJValidationKeyPath,
        itemTitleKey: String
    ) throws {
        for element in value {
            guard let checkable = element as? any HasContentCheckable else { continue }
            let title = SBJCollectionItemIdentification.configuredTitle(
                for: element,
                itemTitleKey: itemTitleKey
            )
            try checkable.invariant(at: keyPath.appending(element: element, title: title))
        }
    }

    public static func validationError<T>(_ value: T, at keyPath: SBJValidationKeyPath) -> SBJValidationError? {
        do {
            try validate(value, at: keyPath)
            return nil
        } catch let error as SBJValidationError {
            return error
        } catch {
            return SBJValidationError(error.localizedDescription, at: keyPath)
        }
    }

    public static func require(
        _ condition: @autoclosure () -> Bool,
        at keyPath: SBJValidationKeyPath,
        _ message: String
    ) throws {
        guard condition() else { throw SBJValidationError(message, at: keyPath) }
    }

    private static func require<Value>(
        _ condition: @autoclosure () -> Bool,
        value: Value,
        at keyPath: SBJValidationKeyPath,
        _ message: String
    ) throws {
        guard condition() else { throw SBJValidationError(value, at: keyPath, message) }
    }

    public static func requireRange(_ value: Int, _ range: ClosedRange<Int>, at keyPath: SBJValidationKeyPath) throws {
        try require(range.contains(value), value: value, at: keyPath, "must be in \(range.lowerBound)...\(range.upperBound)")
    }

    public static func requireRange(_ value: Int?, _ range: ClosedRange<Int>, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireRange(value, range, at: keyPath) }
    }

    public static func requireRange(_ values: [Int], _ range: ClosedRange<Int>, at keyPath: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() {
            try requireRange(value, range, at: keyPath.appending(index: index))
        }
    }

    public static func requireMinimum(_ value: Int, _ minimum: Int, at keyPath: SBJValidationKeyPath) throws {
        try require(value >= minimum, value: value, at: keyPath, "must be at least \(minimum)")
    }

    public static func requireMinimum(_ value: Int?, _ minimum: Int, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireMinimum(value, minimum, at: keyPath) }
    }

    public static func requireMinimum(_ values: [Int], _ minimum: Int, at keyPath: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() {
            try requireMinimum(value, minimum, at: keyPath.appending(index: index))
        }
    }


    private static func requireIntegerRange<T: FixedWidthInteger>(
        _ value: T, _ range: ClosedRange<Int>, at keyPath: SBJValidationKeyPath
    ) throws {
        guard let converted = Int(exactly: value) else {
            throw SBJValidationError(value, at: keyPath, "must be in \(range.lowerBound)...\(range.upperBound)")
        }
        try requireRange(converted, range, at: keyPath)
    }

    public static func requireRange<T: FixedWidthInteger>(_ value: T, _ range: ClosedRange<Int>, at keyPath: SBJValidationKeyPath) throws {
        try requireIntegerRange(value, range, at: keyPath)
    }

    public static func requireRange<T: FixedWidthInteger>(_ value: T?, _ range: ClosedRange<Int>, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireIntegerRange(value, range, at: keyPath) }
    }

    public static func requireRange<T: FixedWidthInteger>(_ values: [T], _ range: ClosedRange<Int>, at keyPath: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() {
            try requireIntegerRange(value, range, at: keyPath.appending(index: index))
        }
    }

    private static func requireIntegerMinimum<T: FixedWidthInteger>(
        _ value: T, _ minimum: Int, at keyPath: SBJValidationKeyPath
    ) throws {
        if let converted = Int(exactly: value) {
            try require(converted >= minimum, value: value, at: keyPath, "must be at least \(minimum)")
            return
        }
        // An unsigned value that does not fit Int is necessarily greater than Int.max
        // and therefore satisfies any Int minimum.
        if T.min == 0 { return }
        throw SBJValidationError(value, at: keyPath, "must be at least \(minimum)")
    }

    public static func requireMinimum<T: FixedWidthInteger>(_ value: T, _ minimum: Int, at keyPath: SBJValidationKeyPath) throws {
        try requireIntegerMinimum(value, minimum, at: keyPath)
    }

    public static func requireMinimum<T: FixedWidthInteger>(_ value: T?, _ minimum: Int, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireIntegerMinimum(value, minimum, at: keyPath) }
    }

    public static func requireMinimum<T: FixedWidthInteger>(_ values: [T], _ minimum: Int, at keyPath: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() {
            try requireIntegerMinimum(value, minimum, at: keyPath.appending(index: index))
        }
    }

    public static func requireRange(_ value: Double, _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        try require(value.isFinite && range.contains(value), value: value, at: keyPath, "must be finite and in \(range.lowerBound)...\(range.upperBound)")
    }

    public static func requireRange(_ value: Double?, _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireRange(value, range, at: keyPath) }
    }

    public static func requireRange(_ values: [Double], _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() {
            try requireRange(value, range, at: keyPath.appending(index: index))
        }
    }

    public static func requireRange(_ value: Float, _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        let number = Double(value)
        try require(number.isFinite && range.contains(number), value: value, at: keyPath, "must be finite and in \(range.lowerBound)...\(range.upperBound)")
    }

    public static func requireRange(_ value: Float?, _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireRange(value, range, at: keyPath) }
    }


    public static func requireRange(_ value: CGFloat, _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        let number = Double(value)
        try require(number.isFinite && range.contains(number), value: value, at: keyPath, "must be finite and in \(range.lowerBound)...\(range.upperBound)")
    }

    public static func requireRange(_ value: CGFloat?, _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireRange(value, range, at: keyPath) }
    }

    public static func requireRange(_ value: Decimal, _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        let number = NSDecimalNumber(decimal: value).doubleValue
        try require(number.isFinite && range.contains(number), value: value, at: keyPath, "must be finite and in \(range.lowerBound)...\(range.upperBound)")
    }

    public static func requireRange(_ value: Decimal?, _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireRange(value, range, at: keyPath) }
    }

    public static func requireRange<T: BinaryFloatingPoint>(_ values: [T], _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() {
            try requireRange(Double(value), range, at: keyPath.appending(index: index))
        }
    }

    public static func requireRange(_ values: [Decimal], _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() {
            try requireRange(value, range, at: keyPath.appending(index: index))
        }
    }

    public static func requireMinimum(_ value: Double, _ minimum: Double, at keyPath: SBJValidationKeyPath) throws {
        try require(value.isFinite && value >= minimum, value: value, at: keyPath, "must be finite and at least \(minimum)")
    }

    public static func requireMinimum(_ value: Double?, _ minimum: Double, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireMinimum(value, minimum, at: keyPath) }
    }

    public static func requireMinimum(_ value: Float, _ minimum: Double, at keyPath: SBJValidationKeyPath) throws {
        let number = Double(value)
        try require(number.isFinite && number >= minimum, value: value, at: keyPath, "must be finite and at least \(minimum)")
    }

    public static func requireMinimum(_ value: Float?, _ minimum: Double, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireMinimum(value, minimum, at: keyPath) }
    }

    public static func requireMinimum(_ value: CGFloat, _ minimum: Double, at keyPath: SBJValidationKeyPath) throws {
        let number = Double(value)
        try require(number.isFinite && number >= minimum, value: value, at: keyPath, "must be finite and at least \(minimum)")
    }

    public static func requireMinimum(_ value: CGFloat?, _ minimum: Double, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireMinimum(value, minimum, at: keyPath) }
    }

    public static func requireMinimum(_ value: Decimal, _ minimum: Double, at keyPath: SBJValidationKeyPath) throws {
        let number = NSDecimalNumber(decimal: value).doubleValue
        try require(number.isFinite && number >= minimum, value: value, at: keyPath, "must be finite and at least \(minimum)")
    }

    public static func requireMinimum(_ value: Decimal?, _ minimum: Double, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireMinimum(value, minimum, at: keyPath) }
    }

    public static func requireMinimum<T: BinaryFloatingPoint>(_ values: [T], _ minimum: Double, at keyPath: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() {
            try requireMinimum(Double(value), minimum, at: keyPath.appending(index: index))
        }
    }

    public static func requireMinimum(_ values: [Decimal], _ minimum: Double, at keyPath: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() {
            try requireMinimum(value, minimum, at: keyPath.appending(index: index))
        }
    }

    public static func requirePresent<T>(_ value: T?, required: Bool, at keyPath: SBJValidationKeyPath) throws {
        if required { try require(value != nil, value: value, at: keyPath, "must be present") }
    }

    public static func requireNonzero(_ value: UUID, at keyPath: SBJValidationKeyPath) throws {
        try require(!value.sbjIsZero, value: value, at: keyPath, "must not be the zero UUID")
    }

    public static func requireNonzero(_ value: UUID?, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireNonzero(value, at: keyPath) }
    }

    public static func requireRange(_ value: Date, _ range: ClosedRange<Date>, at keyPath: SBJValidationKeyPath) throws {
        try require(range.contains(value), value: value, at: keyPath, "must be in the declared date range")
    }

    public static func requireRange(_ value: Date?, _ range: ClosedRange<Date>, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireRange(value, range, at: keyPath) }
    }

    /// Requires a URL to belong to one of the declared broad URL categories.
    /// This is an explicit invariant check; it never intercepts assignment or editing.
    public static func requireURL(_ value: URL, allowed: Set<SBJURLKind>, at keyPath: SBJValidationKeyPath) throws {
        let kind: SBJURLKind?
        if value.isFileURL {
            kind = .file
        } else if value.scheme != nil {
            kind = .network
        } else {
            kind = nil
        }
        try require(kind.map { allowed.contains($0) } == true, value: value, at: keyPath, "must be an allowed URL kind")
    }

    public static func requireURL(_ value: URL?, allowed: Set<SBJURLKind>, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireURL(value, allowed: allowed, at: keyPath) }
    }

    public static func requireText(_ value: String, minLength: Int?, maxLength: Int?, at keyPath: SBJValidationKeyPath) throws {
        try requireText(value, minLength: minLength, maxLength: maxLength, trimming: .none, at: keyPath)
    }

    public static func requireText(
        _ value: String,
        minLength: Int?,
        maxLength: Int?,
        trimming: SBJStringTrimming,
        at keyPath: SBJValidationKeyPath
    ) throws {
        let constrainedValue = trimming.apply(to: value)
        if let minLength {
            try require(constrainedValue.count >= minLength, value: value, at: keyPath, "must contain at least \(minLength) characters")
        }
        if let maxLength {
            try require(constrainedValue.count <= maxLength, value: value, at: keyPath, "must contain at most \(maxLength) characters")
        }
    }

    /// Applies text constraints when an optional value is present. Absence is
    /// governed separately by `@SBJOptional(required:)`, preserving the
    /// distinction between presence and the validity of present content.
    public static func requireText(_ value: String?, minLength: Int?, maxLength: Int?, at keyPath: SBJValidationKeyPath) throws {
        if let value {
            try requireText(value, minLength: minLength, maxLength: maxLength, at: keyPath)
        }
    }

    public static func requireText(
        _ value: String?,
        minLength: Int?,
        maxLength: Int?,
        trimming: SBJStringTrimming,
        at keyPath: SBJValidationKeyPath
    ) throws {
        if let value {
            try requireText(value, minLength: minLength, maxLength: maxLength, trimming: trimming, at: keyPath)
        }
    }

    public static func requireCount<C: Collection>(
        _ value: C,
        minCount: Int?,
        maxCount: Int?,
        at keyPath: SBJValidationKeyPath
    ) throws {
        if let minCount {
            try require(value.count >= minCount, value: value.count, at: keyPath, "must contain at least \(minCount) elements")
        }
        if let maxCount {
            try require(value.count <= maxCount, value: value.count, at: keyPath, "must contain at most \(maxCount) elements")
        }
    }

    public static func requireUnique<C: Collection>(
        _ values: C,
        at keyPath: SBJValidationKeyPath,
        _ message: String = "must contain unique values"
    ) throws where C.Element: Hashable {
        var seen = Set<C.Element>()
        for (index, value) in values.enumerated() {
            guard seen.insert(value).inserted else {
                throw SBJValidationError(value, at: keyPath.appending(index: index), message)
            }
        }
    }

    public static func requireUnique<C: Collection, Key: Hashable>(
        _ values: C,
        by keyPathToKey: KeyPath<C.Element, Key>,
        at keyPath: SBJValidationKeyPath,
        _ message: String = "must contain values with unique keys"
    ) throws {
        var seen = Set<Key>()
        for (index, value) in values.enumerated() {
            let key = value[keyPath: keyPathToKey]
            guard seen.insert(key).inserted else {
                throw SBJValidationError(key, at: keyPath.appending(index: index), message)
            }
        }
    }

    /// Applies byte-count business rules to `Data`. This is available before the
    /// dedicated Data annotation/editor so custom consumers can use the same
    /// invariant implementation.
    public static func requireData(
        _ value: Data,
        min: Int? = nil,
        max: Int? = nil,
        modulo: Int? = nil,
        at keyPath: SBJValidationKeyPath
    ) throws {
        if let min {
            try require(value.count >= min, value: value.count, at: keyPath, "must contain at least \(min) bytes")
        }
        if let max {
            try require(value.count <= max, value: value.count, at: keyPath, "must contain at most \(max) bytes")
        }
        if let modulo {
            try require(modulo > 0, at: keyPath, "modulo must be greater than zero")
            try require(value.count.isMultiple(of: modulo), value: value.count, at: keyPath, "byte count must be a multiple of \(modulo)")
        }
    }

    public static func requireData(
        _ value: Data?,
        min: Int? = nil,
        max: Int? = nil,
        modulo: Int? = nil,
        at keyPath: SBJValidationKeyPath
    ) throws {
        if let value { try requireData(value, min: min, max: max, modulo: modulo, at: keyPath) }
    }
}

// MARK: - Handwritten invariant conveniences

public func require(
    _ condition: @autoclosure () -> Bool,
    _ keyPath: SBJValidationKeyPath,
    _ requirement: String
) throws {
    try SBJInvariantCheck.require(condition(), at: keyPath, requirement)
}

public extension String {
    func requireMeaningful(at keyPath: SBJValidationKeyPath) throws {
        guard trimmingCharacters(in: .whitespacesAndNewlines).hasContent else {
            throw SBJValidationError(self, at: keyPath, "must contain non-whitespace text")
        }
    }
}


public func requireUnique<T: Hashable>(
    _ values: [T],
    _ keyPath: SBJValidationKeyPath,
    _ requirement: String = "must contain unique values"
) throws {
    try SBJInvariantCheck.requireUnique(values, at: keyPath, requirement)
}

public func requireUnique<Element, Key: Hashable>(
    _ values: [Element],
    by keyPathToKey: KeyPath<Element, Key>,
    _ keyPath: SBJValidationKeyPath,
    _ requirement: String = "must contain values with unique keys"
) throws {
    try SBJInvariantCheck.requireUnique(values, by: keyPathToKey, at: keyPath, requirement)
}
