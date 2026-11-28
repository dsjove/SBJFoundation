import Foundation
import SBJLocalization
import SBJStructure

enum SBJLeafMutationError: LocalizedError {
    case notLeaf, resolution(String), immutable, unsupportedValue, invalidValue
    var errorDescription: String? {
        switch self {
        case .notLeaf: "Select an existing writable leaf."
        case .resolution(let message): message
        case .immutable: "The selected value is read-only."
        case .unsupportedValue: "This leaf type has no mutation adapter."
        case .invalidValue: "The replacement is invalid for this leaf type."
        }
    }
}

/// Conversion is driven by the actual typed occurrence, not by generated type names.
/// No live model writes are performed here.
enum SBJLeafMutation {
    struct Proposal {
        let location: [String]
        let replacement: Any
        let change: SBJFieldChangeSummary
    }

    static func prepare<Root>(_ root: Root, snapshot: SBJSemanticReadSnapshot,
                              keyPath: [String], value: String) throws -> Proposal {
        let target = try snapshot.resolveLeaf(keyPath)
        guard let structured = root as? any SBJStructured else { throw SBJLeafMutationError.notLeaf }
        let matches = SBJStructuralTraversal.descendants(in: structured, options: snapshot.traversalOptions).filter { $0.locationPath == target.location }
        guard matches.count == 1, let occurrence = matches.first else { throw SBJLeafMutationError.notLeaf }
        guard occurrence.isWritableProperty else { throw SBJLeafMutationError.immutable }
        let replacement = try convert(value, matching: occurrence.value)
        return .init(location: target.location, replacement: replacement,
                     change: .init(field: occurrence.displayPath.joined(separator: " / "),
                                   oldValue: preview(occurrence.value), proposedValue: preview(replacement)))
    }

    private static func preview(_ value: Any) -> String {
        if let optional = value as? any SBJLeafOptional, let wrapped = optional.leafWrapped { return preview(wrapped) }
        if let presented = value as? any SBJTextPresentable { return presented.presentedValue }
        return SBJSemanticScalarReading.value(value, type: Swift.type(of: value))?.label ?? String(describing: value)
    }

    static func convert(_ input: String, matching old: Any) throws -> Any {
        if let optional = old as? any SBJLeafOptional { return try optional.leafReplacement(input) }
        if let unit = old as? any SBJLeafMeasurement { return try unit.leafAmount(input) }
        let type = Swift.type(of: old)
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if type == String.self { return input }
        if type == Int.self { return try SBJCollectionScalar.parse(input, as: Int.self) }
        if type == Int64.self { return try SBJCollectionScalar.parse(input, as: Int64.self) }
        if type == Double.self { return try SBJCollectionScalar.parse(input, as: Double.self) }
        if type == Float.self { return try SBJCollectionScalar.parse(input, as: Float.self) }
        if type == Bool.self { return try SBJCollectionScalar.parse(input, as: Bool.self) }
        if type == Int8.self, let x = Int8(text) { return x }
        if type == Int16.self, let x = Int16(text) { return x }
        if type == Int32.self, let x = Int32(text) { return x }
        if type == UInt.self, let x = UInt(text) { return x }
        if type == UInt8.self, let x = UInt8(text) { return x }
        if type == UInt16.self, let x = UInt16(text) { return x }
        if type == UInt32.self, let x = UInt32(text) { return x }
        if type == UInt64.self, let x = UInt64(text) { return x }
        if type == CGFloat.self, let x = Double(text), x.isFinite { return CGFloat(x) }
        if type == Decimal.self, let x = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), !x.isNaN,
           text.range(of: #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"#, options: .regularExpression) != nil { return x }
        if type == Date.self {
            let formatter = ISO8601DateFormatter()
            if let x = formatter.date(from: text) { return x }
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let x = formatter.date(from: text) { return x }
        }
        if type == UUID.self, let x = UUID(uuidString: text) { return x }
        if let cases = type as? any CaseIterable.Type {
            let matches = cases.allCases.compactMap { candidate -> Any? in
                let named = candidate as? any SBJEnumCaseIdentifiable
                let info = named.flatMap { Swift.type(of: $0).sbjCaseNomenclature(for: $0.sbjCaseName) }
                let labels = [named?.sbjCaseName, info?.nonEmptyTitle,
                              SBJSemanticScalarReading.value(candidate, type: type)?.label].compactMap { $0 } + (info?.aliases ?? [])
                return labels.contains(where: { $0.caseInsensitiveCompare(text) == .orderedSame }) ? candidate : nil
            }
            guard matches.count == 1, let candidate = matches.first else { throw SBJLeafMutationError.invalidValue }
            return candidate
        }
        throw SBJLeafMutationError.unsupportedValue
    }
}

private protocol SBJLeafOptional {
    var leafWrapped: Any? { get }
    func leafReplacement(_ input: String) throws -> Any
}
extension Optional: SBJLeafOptional {
    fileprivate var leafWrapped: Any? { map { $0 as Any } }
    fileprivate func leafReplacement(_ input: String) throws -> Any {
        guard let wrapped = self, let replacement = try SBJLeafMutation.convert(input, matching: wrapped) as? Wrapped else {
            throw SBJLeafMutationError.invalidValue
        }
        return Optional.some(replacement) as Any
    }
}

/// Atomic measurements accept a new amount expressed in their existing unit.
/// Changing units is deliberately not implicit in scalar assignment.
private protocol SBJLeafMeasurement {
    func leafAmount(_ input: String) throws -> Any
}
extension UnitValue: SBJLeafMeasurement {
    fileprivate func leafAmount(_ input: String) throws -> Any {
        guard let amount = Double(input.trimmingCharacters(in: .whitespacesAndNewlines)), amount.isFinite else {
            throw SBJLeafMutationError.invalidValue
        }
        return Self(amount, unit: unit)
    }
}
