import Foundation

/// Typed rules for dictionary entries. Incompatible rules fail to compile
/// in macro-generated invariant code, rather than being ignored at runtime.
public extension SBJInvariantCheck {
    static func requireDictionaryMember(_ value: String, rule: SBJStringRules, at path: SBJValidationKeyPath) throws {
        try requireStringRules(value, rule: rule, at: path)
    }
    static func requireDictionaryMember<T: FixedWidthInteger>(_ value: T, rule: SBJIntegerRules, at path: SBJValidationKeyPath) throws {
        if let min = rule.min { try requireMinimum(value, min, at: path) }
        if let max = rule.max { try requireMaximum(value, max, at: path) }
    }
    static func requireDictionaryMember<T: BinaryFloatingPoint>(_ value: T, rule: SBJNumberRules, at path: SBJValidationKeyPath) throws {
        let value = Double(value)
        if let min = rule.min { try requireMinimum(value, min, at: path) }
        if let max = rule.max { try requireMaximum(value, max, at: path) }
    }
    static func requireDictionaryMember(_ value: Decimal, rule: SBJNumberRules, at path: SBJValidationKeyPath) throws {
        if let min = rule.min { try requireMinimum(value, min, at: path) }
        if let max = rule.max { try requireMaximum(value, max, at: path) }
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
    static func requireDictionaryMember(_ value: String?, rule: SBJStringRules, at path: SBJValidationKeyPath) throws {
        if let value { try requireDictionaryMember(value, rule: rule, at: path) }
    }
    static func requireDictionaryMember<T: FixedWidthInteger>(_ value: T?, rule: SBJIntegerRules, at path: SBJValidationKeyPath) throws {
        if let value { try requireDictionaryMember(value, rule: rule, at: path) }
    }
    static func requireDictionaryMember<T: BinaryFloatingPoint>(_ value: T?, rule: SBJNumberRules, at path: SBJValidationKeyPath) throws {
        if let value { try requireDictionaryMember(value, rule: rule, at: path) }
    }
    static func requireDictionaryMember(_ value: Decimal?, rule: SBJNumberRules, at path: SBJValidationKeyPath) throws {
        if let value { try requireDictionaryMember(value, rule: rule, at: path) }
    }
    static func requireDictionaryMember(_ value: UUID?, rule: SBJUUIDRules, at path: SBJValidationKeyPath) throws {
        if let value { try requireDictionaryMember(value, rule: rule, at: path) }
    }
    static func requireDictionaryMember(_ value: URL?, rule: SBJURLRules, at path: SBJValidationKeyPath) throws {
        if let value { try requireDictionaryMember(value, rule: rule, at: path) }
    }
    static func requireDictionaryMember(_ value: Date?, rule: SBJDateRules, at path: SBJValidationKeyPath) throws {
        if let value { try requireDictionaryMember(value, rule: rule, at: path) }
    }
    static func requireDictionaryMember(_ value: Data?, rule: SBJDataRules, at path: SBJValidationKeyPath) throws {
        if let value { try requireDictionaryMember(value, rule: rule, at: path) }
    }
}
