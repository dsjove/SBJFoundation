import Foundation

/// Portable configuration values associated with structural annotations.
/// The annotations keep explicit arguments; their generated metadata uses these values.
public struct SBJStringRules: Codable, Sendable, Equatable {
    public var minLength: Int?
    public var maxLength: Int?
    public var trimming: SBJStringTrimming
    public init(minLength: Int? = nil, maxLength: Int? = nil, trimming: SBJStringTrimming = .none) {
        self.minLength = minLength; self.maxLength = maxLength; self.trimming = trimming
    }
}

public struct SBJStringPresentationValue: Codable, Sendable, Equatable {
    public var style: SBJStringStyle
    public var autocorrect: SBJTextAutocorrection
    public var capitalization: SBJTextCapitalization
    public init(style: SBJStringStyle = .singleLine, autocorrect: SBJTextAutocorrection = .automatic, capitalization: SBJTextCapitalization = .automatic) {
        self.style = style; self.autocorrect = autocorrect; self.capitalization = capitalization
    }
}

public struct SBJDataRules: Codable, Sendable, Equatable {
    public var min: Int?
    public var max: Int?
    public var modulo: Int?
    public init(min: Int? = nil, max: Int? = nil, modulo: Int? = nil) {
        self.min = min; self.max = max; self.modulo = modulo
    }
}

/// Direction required for an array snapshot to be sorted according to Comparable.
public enum SBJSortDirection: String, Codable, Sendable, Equatable {
    case ascending
    case descending
}

/// Size constraints for an array. Uniqueness and ordering are intentionally
/// separate until their typed-key-path and mutation semantics are designed.
public struct SBJArrayRules: Codable, Sendable, Equatable {
    public var minCount: Int?
    public var maxCount: Int?
    public var sorted: SBJSortDirection?
    public init(minCount: Int? = nil, maxCount: Int? = nil, sorted: SBJSortDirection? = nil) {
        self.minCount = minCount; self.maxCount = maxCount; self.sorted = sorted
    }
}

public struct SBJSetRules: Codable, Sendable, Equatable {
    public var minCount: Int?
    public var maxCount: Int?
    public init(minCount: Int? = nil, maxCount: Int? = nil) {
        self.minCount = minCount; self.maxCount = maxCount
    }
}

public struct SBJDictionaryRules: Codable, Sendable, Equatable {
    public var minCount: Int?
    public var maxCount: Int?
    public init(minCount: Int? = nil, maxCount: Int? = nil) {
        self.minCount = minCount; self.maxCount = maxCount
    }
}

public struct SBJOptionalRules: Codable, Sendable, Equatable {
    public var required: Bool
    public init(required: Bool = true) { self.required = required }
}

public struct SBJUUIDRules: Codable, Sendable, Equatable {
    public var nonzero: Bool
    public init(nonzero: Bool = true) { self.nonzero = nonzero }
}

public struct SBJURLRules: Codable, Sendable, Equatable {
    public var allowed: Set<SBJURLKind>
    public init(allowed: Set<SBJURLKind>) { self.allowed = allowed }
}

public struct SBJDateRules: Codable, Sendable, Equatable {
    public var range: ClosedRange<Date>
    public init(range: ClosedRange<Date>) { self.range = range }
}

public struct SBJColorPresentationValue: Codable, Sendable, Equatable {
    public var alpha: Bool
    public init(alpha: Bool) { self.alpha = alpha }
}

public struct SBJUnitValuePresentationValue: Codable, Sendable, Equatable {
    public var mode: SBJUnitValuePresentationMode
    public init(mode: SBJUnitValuePresentationMode = .fixedUnit) { self.mode = mode }
}


/// A numeric rule may specify an inclusive range or a lower bound.
/// The public annotation overloads select one form.
public struct SBJIntegerRules: Codable, Sendable, Equatable {
    public var range: ClosedRange<Int>?
    public var min: Int?
    public init(range: ClosedRange<Int>? = nil, min: Int? = nil) {
        self.range = range; self.min = min
    }
}

public struct SBJNumberRules: Codable, Sendable, Equatable {
    public var range: ClosedRange<Double>?
    public var min: Double?
    public init(range: ClosedRange<Double>? = nil, min: Double? = nil) {
        self.range = range; self.min = min
    }
}

/// Serializable, type-specific descriptions of dictionary member rules.
/// Generated invariant checks remain statically typed; this enum is metadata only.
public enum SBJDictionaryMemberRuleValue: Codable, Sendable, Equatable {
    case string(SBJStringRules)
    case integer(SBJIntegerRules)
    case number(SBJNumberRules)
    case uuid(SBJUUIDRules)
    case url(SBJURLRules)
    case date(SBJDateRules)
    case data(SBJDataRules)
}

/// A rule applicable to a dictionary key or value. The annotation macro emits
/// statically typed checks for each concrete rule; no runtime type erasure is
/// used to decide whether a rule is applicable.
public protocol SBJDictionaryMemberRule: Sendable {}
extension SBJStringRules: SBJDictionaryMemberRule {}
extension SBJIntegerRules: SBJDictionaryMemberRule {}
extension SBJNumberRules: SBJDictionaryMemberRule {}
extension SBJUUIDRules: SBJDictionaryMemberRule {}
extension SBJURLRules: SBJDictionaryMemberRule {}
extension SBJDateRules: SBJDictionaryMemberRule {}
extension SBJDataRules: SBJDictionaryMemberRule {}
