import Foundation

/// Human-readable annotation descriptions shared by reports and other consumers.
/// Omits absent attributes, unnecessary type names, and Swift Optional wrappers.
private enum SBJAnnotationText {
    static func words(_ value: String) -> String {
        let short = value.split(separator: ".").last.map(String.init) ?? value
        var result = ""
        for char in short {
            if char.isUppercase && !result.isEmpty && result.last != " " && (result.last?.isLowercase == true || result.last?.isNumber == true) { result.append(" ") }
            result.append(char)
        }
        return result.replacingOccurrences(of: "_", with: " ").lowercased()
    }
    static func join(_ elements: [String]) -> String { elements.isEmpty ? "No restrictions" : elements.joined(separator: " · ") }
    static func item(_ label: String, _ value: Int?) -> String? { value.map { "\(label) \($0)" } }
    static func range<T>(_ label: String, _ value: ClosedRange<T>?) -> String? where T: Comparable & CustomStringConvertible {
        value.map { "\(label) \($0.lowerBound)–\($0.upperBound)" }
    }
    static func permission(_ name: String, _ enabled: Bool) -> String { "\(name): \(enabled ? "yes" : "no")" }
}

extension SBJStringRules: CustomStringConvertible {
    public var description: String { SBJAnnotationText.join([
        SBJAnnotationText.item("Minimum length", minLength), SBJAnnotationText.item("Maximum length", maxLength),
        trimming == .none ? nil : "Trim \(SBJAnnotationText.words(trimming.rawValue))"
    ].compactMap { $0 }) }
}
extension SBJDataRules: CustomStringConvertible {
    public var description: String { SBJAnnotationText.join([
        SBJAnnotationText.item("Minimum bytes", min), SBJAnnotationText.item("Maximum bytes", max), SBJAnnotationText.item("Multiple of", modulo)
    ].compactMap { $0 }) }
}
extension SBJArrayRules: CustomStringConvertible {
    public var description: String { SBJAnnotationText.join([
        SBJAnnotationText.item("Minimum items", minCount), SBJAnnotationText.item("Maximum items", maxCount),
        sorted.map { "Sorted \(SBJAnnotationText.words($0.rawValue))" }
    ].compactMap { $0 }) }
}
extension SBJSetRules: CustomStringConvertible {
    public var description: String { SBJAnnotationText.join([
        SBJAnnotationText.item("Minimum items", minCount), SBJAnnotationText.item("Maximum items", maxCount)
    ].compactMap { $0 }) }
}
extension SBJDictionaryRules: CustomStringConvertible {
    public var description: String { SBJAnnotationText.join([
        SBJAnnotationText.item("Minimum entries", minCount), SBJAnnotationText.item("Maximum entries", maxCount)
    ].compactMap { $0 }) }
}
extension SBJOptionalRules: CustomStringConvertible {
    public var description: String { required ? "Required" : "Optional" }
}
extension SBJUUIDRules: CustomStringConvertible {
    public var description: String { nonzero ? "Nonzero UUID" : "Zero UUID allowed" }
}
extension SBJURLRules: CustomStringConvertible {
    public var description: String { "Allowed: " + allowed.map { SBJAnnotationText.words(String(describing: $0)) }.sorted().joined(separator: ", ") }
}
extension SBJDateRules: CustomStringConvertible {
    public var description: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return "From \(f.string(from: range.lowerBound)) through \(f.string(from: range.upperBound))"
    }
}
extension SBJIntegerRules: CustomStringConvertible {
    public var description: String { SBJAnnotationText.join([
        SBJAnnotationText.range("Range", range), SBJAnnotationText.item("Minimum", min)
    ].compactMap { $0 }) }
}
extension SBJNumberRules: CustomStringConvertible {
    public var description: String { SBJAnnotationText.join([
        SBJAnnotationText.range("Range", range), min.map { "Minimum \($0)" }
    ].compactMap { $0 }) }
}
extension SBJStringPresentationValue: CustomStringConvertible {
    public var description: String { SBJAnnotationText.join([
        "Style: \(SBJAnnotationText.words(style.rawValue))",
        autocorrect == .automatic ? nil : "Autocorrection: \(SBJAnnotationText.words(autocorrect.rawValue))",
        capitalization == .automatic ? nil : "Capitalization: \(SBJAnnotationText.words(capitalization.rawValue))"
    ].compactMap { $0 }) }
}
extension SBJColorPresentationValue: CustomStringConvertible {
    public var description: String { alpha ? "Alpha enabled" : "Opaque color" }
}
extension SBJUnitValuePresentationValue: CustomStringConvertible {
    public var description: String { "Mode: \(SBJAnnotationText.words(String(describing: mode)))" }
}
extension SBJFieldPresentationValue: CustomStringConvertible {
    public var description: String { SBJAnnotationText.join([
        name.map { "Name: \($0)" }, autoExpand ? "Auto expand" : nil, exclude ? "Excluded" : nil
    ].compactMap { $0 }) }
}
extension SBJArrayPresentationValue: CustomStringConvertible {
    public var description: String { SBJAnnotationText.join([
        SBJAnnotationText.permission("Insert", insertable), SBJAnnotationText.permission("Remove", removable), SBJAnnotationText.permission("Reorder", reorderable)
    ]) }
}
extension SBJSetPresentationValue: CustomStringConvertible {
    public var description: String { SBJAnnotationText.join([
        SBJAnnotationText.permission("Insert", insertable), SBJAnnotationText.permission("Remove", removable),
        sort.map { "Sort: \(SBJAnnotationText.words($0.rawValue))" }
    ].compactMap { $0 }) }
}
extension SBJDictionaryPresentationValue: CustomStringConvertible {
    public var description: String { SBJAnnotationText.join([
        SBJAnnotationText.permission("Insert", insertable), SBJAnnotationText.permission("Remove", removable),
        sort.map { "Sort: \(SBJAnnotationText.words($0.rawValue)) by \(SBJAnnotationText.words(sortBy.rawValue))" },
        key.map { "Key: \($0.description)" }, value.map { "Value: \($0.description)" }
    ].compactMap { $0 }) }
}
extension SBJDictionaryMemberRuleValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .string(let value): return "Text: \(value)"
        case .integer(let value): return "Integer: \(value)"
        case .number(let value): return "Number: \(value)"
        case .uuid(let value): return "UUID: \(value)"
        case .url(let value): return "URL: \(value)"
        case .date(let value): return "Date: \(value)"
        case .data(let value): return "Data: \(value)"
        }
    }
}

extension SBJPropertyConstraint: CustomStringConvertible {
    public var description: String {
        switch self {
        case .stringRules(let v): return "Text · \(v)"
        case .integerRules(let v): return "Integer · \(v)"
        case .numberRules(let v): return "Number · \(v)"
        case .optionalRules(let v): return v.description
        case .unitMutable(let v): return v ? "Unit can change" : "Unit cannot change"
        case .defaultUnit(let v): return "Default unit · \(SBJAnnotationText.words(String(describing: v)))"
        case .unitSystem(let v): return "Unit system · \(SBJAnnotationText.words(String(describing: v)))"
        case .arrayRules(let v): return "Array · \(v)"
        case .setRules(let v): return "Set · \(v)"
        case .dictionaryRules(let v): return "Dictionary · \(v)"
        case .dictionaryKeyRule(let v): return "Dictionary key · \(v)"
        case .dictionaryValueRule(let v): return "Dictionary value · \(v)"
        case .unique: return "Unique elements"
        case .uniqueBy(let v): return "Unique by · \(v)"
        case .dataRules(let v): return "Data · \(v)"
        case .uuidRules(let v): return v.description
        case .dateRules(let v): return "Date · \(v)"
        case .urlRules(let v): return "URL · \(v)"
        }
    }
}
extension SBJPropertyHint: CustomStringConvertible {
    public var description: String {
        switch self {
        case .fieldPresentation(let v): return "Field · \(v)"
        case .elementFieldPresentation(let v): return "Element field · \(v)"
        case .arrayPresentation(let v): return "Array · \(v)"
        case .setPresentation(let v): return "Set · \(v)"
        case .dictionaryPresentation(let v): return "Dictionary · \(v)"
        case .stringPresentation(let v): return "Text · \(v)"
        case .unitValuePresentation(let v): return "Measurement · \(v)"
        case .colorPresentation(let v): return "Color · \(v)"
        case .itemTitle(let v): return "Item title · \(v)"
        }
    }
}
