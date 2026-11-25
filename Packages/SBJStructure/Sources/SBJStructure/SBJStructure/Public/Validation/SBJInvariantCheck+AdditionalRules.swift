import Foundation

public extension SBJInvariantCheck {
    /// Inclusive upper bound, including fixed-width integers larger than Int.max.
    static func requireMaximum<T: FixedWidthInteger>(_ value: T, _ maximum: Int, at path: SBJValidationKeyPath) throws {
        let valid: Bool
        if let bound = T(exactly: maximum) {
            valid = value <= bound
        } else {
            // The bound lies outside T's representable range.
            valid = maximum >= 0
        }
        guard valid else { throw SBJValidationError(value, at: path, "must be at most \(maximum)") }
    }

    static func requireMaximum<T: FixedWidthInteger>(_ value: T?, _ maximum: Int, at path: SBJValidationKeyPath) throws {
        if let value { try requireMaximum(value, maximum, at: path) }
    }

    static func requireMaximum<T: FixedWidthInteger>(_ values: [T], _ maximum: Int, at path: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() { try requireMaximum(value, maximum, at: path.appending(index: index)) }
    }

    static func requireMaximum<T: BinaryFloatingPoint>(_ value: T, _ maximum: Double, at path: SBJValidationKeyPath) throws {
        guard value.isFinite, Double(value) <= maximum else {
            throw SBJValidationError(value, at: path, "must be finite and at most \(maximum)")
        }
    }

    static func requireMaximum<T: BinaryFloatingPoint>(_ value: T?, _ maximum: Double, at path: SBJValidationKeyPath) throws {
        if let value { try requireMaximum(value, maximum, at: path) }
    }

    static func requireMaximum<T: BinaryFloatingPoint>(_ values: [T], _ maximum: Double, at path: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() { try requireMaximum(value, maximum, at: path.appending(index: index)) }
    }

    static func requireMaximum(_ value: Decimal, _ maximum: Double, at path: SBJValidationKeyPath) throws {
        // Match the existing Decimal range and minimum conversion policy.
        try requireMaximum(NSDecimalNumber(decimal: value).doubleValue, maximum, at: path)
    }

    static func requireMaximum(_ value: Decimal?, _ maximum: Double, at path: SBJValidationKeyPath) throws {
        if let value { try requireMaximum(value, maximum, at: path) }
    }

    static func requireMaximum(_ values: [Decimal], _ maximum: Double, at path: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() { try requireMaximum(value, maximum, at: path.appending(index: index)) }
    }

    static func requireMaximum<T: FixedWidthInteger>(_ values: [T?], _ maximum: Int, at path: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() { try requireMaximum(value, maximum, at: path.appending(index: index)) }
    }
    static func requireMaximum<T: BinaryFloatingPoint>(_ values: [T?], _ maximum: Double, at path: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() { try requireMaximum(value, maximum, at: path.appending(index: index)) }
    }
    static func requireMaximum(_ values: [Decimal?], _ maximum: Double, at path: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() { try requireMaximum(value, maximum, at: path.appending(index: index)) }
    }

    /// Rules apply to normalized text without changing the stored string.
    /// Patterns use ICU regular expression syntax and must match the entire string.
    static func requireStringRules(_ value: String, rule: SBJStringRules, at path: SBJValidationKeyPath) throws {
        try requireText(value, minLength: rule.minLength, maxLength: rule.maxLength, trimming: rule.trimming, at: path)
        let normalized = rule.trimming.apply(to: value)
        if let choices = rule.allowedValues, !choices.contains(normalized) {
            throw SBJValidationError(value, at: path, "must be one of the permitted strings")
        }
        if let pattern = rule.pattern {
            let regex: NSRegularExpression
            do { regex = try NSRegularExpression(pattern: "\\A(?:\(pattern))\\z") }
            catch { throw SBJValidationError(value, at: path, "has an invalid declared regular expression") }
            let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
            guard regex.firstMatch(in: normalized, range: range) != nil else {
                throw SBJValidationError(value, at: path, "must match pattern \(pattern)")
            }
        }
    }

    static func requireStringRules(_ value: String?, rule: SBJStringRules, at path: SBJValidationKeyPath) throws {
        if let value { try requireStringRules(value, rule: rule, at: path) }
    }

    static func requireStringRules(_ values: [String], rule: SBJStringRules, at path: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() { try requireStringRules(value, rule: rule, at: path.appending(index: index)) }
    }

    static func requireStringRules(_ values: [String?], rule: SBJStringRules, at path: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() { try requireStringRules(value, rule: rule, at: path.appending(index: index)) }
    }
}

