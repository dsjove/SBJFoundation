import Foundation

/// Typed rules for dictionary entries. Incompatible rules fail to compile
/// in macro-generated invariant code, rather than being ignored at runtime.
public extension SBJInvariantCheck {
    static func requireDictionaryMember(_ value: String, rule: SBJStringRules, at path: SBJValidationKeyPath) throws {
        try requireText(value, minLength: rule.minLength, maxLength: rule.maxLength, trimming: rule.trimming, at: path)
    }
    static func requireDictionaryMember<T: FixedWidthInteger>(_ value: T, rule: SBJIntegerRules, at path: SBJValidationKeyPath) throws {
        if let range = rule.range { try requireRange(value, range, at: path) }
        if let min = rule.min { try requireMinimum(value, min, at: path) }
    }
    static func requireDictionaryMember(_ value: Double, rule: SBJNumberRules, at path: SBJValidationKeyPath) throws {
        if let range = rule.range { try requireRange(value, range, at: path) }
        if let min = rule.min { try requireMinimum(value, min, at: path) }
    }
    static func requireDictionaryMember(_ value: UUID, rule: SBJUUIDRules, at path: SBJValidationKeyPath) throws {
        if rule.nonzero { try requireNonzero(value, at: path) }
    }
    static func requireDictionaryMember(_ value: URL, rule: SBJURLRules, at path: SBJValidationKeyPath) throws {
        try requireURL(value, allowed: rule.allowed, at: path)
    }
    static func requireDictionaryMember(_ value: Date, rule: SBJDateRules, at path: SBJValidationKeyPath) throws {
        try requireRange(value, rule.range, at: path)
    }
    static func requireDictionaryMember(_ value: Data, rule: SBJDataRules, at path: SBJValidationKeyPath) throws {
        try requireData(value, min: rule.min, max: rule.max, modulo: rule.modulo, at: path)
    }
}
