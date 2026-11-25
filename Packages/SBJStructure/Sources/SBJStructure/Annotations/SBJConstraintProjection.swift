import Foundation

/// Consumer-independent interpretation of property constraints. The original
/// annotations remain authoritative; this projection adds no model storage.
public struct SBJConstraintProjection: Sendable {
    public let constraints: [SBJPropertyConstraint]
    public init(_ constraints: [SBJPropertyConstraint] = []) { self.constraints = constraints }

    public var integerRange: ClosedRange<Int>? {
        let rules = constraints.compactMap { if case .integerRules(let rule) = $0 { return rule }; return nil as SBJIntegerRules? }
        let minimum = rules.compactMap(\.min).max(), maximum = rules.compactMap(\.max).min()
        guard minimum != nil || maximum != nil else { return nil }
        let lower = minimum ?? Int.min, upper = maximum ?? Int.max
        return lower <= upper ? lower...upper : nil
    }
    public var numberRange: ClosedRange<Double>? {
        let rules = constraints.compactMap { if case .numberRules(let rule) = $0 { return rule }; return nil as SBJNumberRules? }
        let minimum = rules.compactMap(\.min).max(), maximum = rules.compactMap(\.max).min()
        guard minimum != nil || maximum != nil else { return nil }
        let lower = minimum ?? -Double.greatestFiniteMagnitude, upper = maximum ?? Double.greatestFiniteMagnitude
        return lower <= upper ? lower...upper : nil
    }
    public var stringRules: [SBJStringRules] {
        constraints.compactMap { if case .stringRules(let rule) = $0 { return rule }; return nil }
    }
    public var textMaximumLength: Int? { stringRules.compactMap(\.maxLength).min() }
    public var dateRange: ClosedRange<Date>? {
        let ranges = constraints.compactMap { if case .dateRules(let rule) = $0 { return rule.range }; return nil as ClosedRange<Date>? }
        guard let lower = ranges.map(\.lowerBound).max(), let upper = ranges.map(\.upperBound).min(), lower <= upper else { return nil }
        return lower...upper
    }
    public var unitMinimum: Double? {
        constraints.compactMap { if case .unitMinimum(let value) = $0 { return value }; return nil as Double? }.max()
    }
    /// Uses exactly the same validation as the generated model invariants.
    public func acceptsString(_ value: String) -> Bool {
        stringRules.allSatisfy { rule in
            (try? SBJInvariantCheck.requireStringRules(value, rule: rule, at: .root)) != nil
        }
    }
    /// Validation for the scalar constraints that can be projected onto a field
    /// or dictionary member. Collection-wide and model-specific invariants
    /// are still evaluated by the generated model validator.
    public func scalarValidationError<Value>(for value: Value) -> SBJValidationError? {
        do {
            for constraint in constraints {
                switch constraint {
                case .stringRules(let rule):
                    if let value = value as? String { try SBJInvariantCheck.requireDictionaryMember(value, rule: rule, at: .root) }
                case .integerRules(let rule):
                    if let value = value as? any FixedWidthInteger { try SBJInvariantCheck.requireDictionaryMember(value, rule: rule, at: .root) }
                case .numberRules(let rule):
                    if let value = value as? Decimal { try SBJInvariantCheck.requireDictionaryMember(value, rule: rule, at: .root) }
                    else if let value = value as? any BinaryFloatingPoint { try SBJInvariantCheck.requireDictionaryMember(value, rule: rule, at: .root) }
                case .uuidRules(let rule):
                    if let value = value as? UUID { try SBJInvariantCheck.requireDictionaryMember(value, rule: rule, at: .root) }
                case .urlRules(let rule):
                    if let value = value as? URL { try SBJInvariantCheck.requireDictionaryMember(value, rule: rule, at: .root) }
                case .dateRules(let rule):
                    if let value = value as? Date { try SBJInvariantCheck.requireDictionaryMember(value, rule: rule, at: .root) }
                case .dataRules(let rule):
                    if let value = value as? Data { try SBJInvariantCheck.requireDictionaryMember(value, rule: rule, at: .root) }
                default: break
                }
            }
            return nil
        } catch let error as SBJValidationError { return error }
        catch { return SBJValidationError(value, at: .root, String(describing: error)) }
    }
    /// Compare a choice and stored string under the declared normalization,
    /// while leaving the original storage intact.
    public func matchesStringChoice(_ choice: String, current: String) -> Bool {
        guard acceptsString(current) else { return false }
        return stringRules.filter { $0.allowedValues != nil }.allSatisfy {
            $0.trimming.apply(to: choice) == $0.trimming.apply(to: current)
        }
    }
    /// nil means no choice restriction; an empty array means no valid choices.
    /// Preserve declaration order and exact spelling, including whitespace.
    public var allowedStrings: [String]? {
        guard let choices = stringRules.compactMap(\.allowedValues).first else { return nil }
        var seen = Set<String>()
        return choices.filter { seen.insert($0).inserted && acceptsString($0) }
    }
    public var dictionaryKey: Self {
        .init(constraints.compactMap { if case .dictionaryKeyRule(let rule) = $0 { return rule.propertyConstraint }; return nil })
    }
    public var dictionaryValue: Self {
        .init(constraints.compactMap { if case .dictionaryValueRule(let rule) = $0 { return rule.propertyConstraint }; return nil })
    }
    /// Stacked member annotations apply to array elements, not to cardinality.
    public var collectionElement: Self {
        .init(constraints.filter {
            switch $0 {
            case .arrayRules, .setRules, .dictionaryRules, .dictionaryKeyRule, .dictionaryValueRule, .unique, .uniqueBy, .optionalRules: return false
            default: return true
            }
        })
    }
}

public extension SBJDictionaryMemberRuleValue {
    var propertyConstraint: SBJPropertyConstraint {
        switch self {
        case .string(let rule): .stringRules(rule)
        case .integer(let rule): .integerRules(rule)
        case .number(let rule): .numberRules(rule)
        case .uuid(let rule): .uuidRules(rule)
        case .url(let rule): .urlRules(rule)
        case .date(let rule): .dateRules(rule)
        case .data(let rule): .dataRules(rule)
        }
    }
}
