import Foundation
import SBJLocalization
import SBJStructure

/// Typed data captured from explicitly supported model values. Exact
/// integers and Decimal values are not routed through Double. No Codable export
/// of an arbitrary model, reflection fallback, or model reconstruction is used.
public indirect enum SBJSemanticValue: Sendable, Equatable {
    case null, bool(Bool), signed(Int64), unsigned(UInt64), number(Double), decimal(Decimal), text(String)
    case array([Self]), object([String: Self])

    /// Direct access for inspection and tests, without encoding the value.
    public subscript(key: String) -> Self? {
        guard case .object(let fields) = self else { return nil }
        return fields[key]
    }

    public var elements: [Self]? {
        guard case .array(let values) = self else { return nil }
        return values
    }

    /// Only scalar values suitable as labels or address components.
    var label: String? {
        switch self {
        case .text(let value): value
        case .bool(let value): String(value)
        case .signed(let value): String(value)
        case .unsigned(let value): String(value)
        case .number(let value): String(value)
        case .decimal(let value): NSDecimalNumber(decimal: value).stringValue
        default: nil
        }
    }
}

/// Explicit leaf adapters. An unfamiliar opaque type is reported as unavailable
/// (or as presentation-only text), not reflected or silently encoded wholesale.
enum SBJSemanticScalarReading {
    static func value(_ value: Any, type: Any.Type) -> SBJSemanticValue? {
        // Match the declared type, not an NSNumber/optional bridge.
        switch type {
        case is String.Type: return (value as? String).map(SBJSemanticValue.text)
        case is Bool.Type: return (value as? Bool).map(SBJSemanticValue.bool)
        case is Decimal.Type: return (value as? Decimal).map(SBJSemanticValue.decimal)
        case is CGFloat.Type: return (value as? CGFloat).map { .number(Double($0)) }
        case is Date.Type:
            guard let date = value as? Date else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return .object(["iso8601": .text(formatter.string(from: date)),
                            "unixSeconds": .number(date.timeIntervalSince1970)])
        case is UUID.Type: return (value as? UUID).map { .text($0.uuidString) }
        case is URL.Type: return (value as? URL).map { .text($0.absoluteString) }
        case is Data.Type: return (value as? Data).map { .text($0.base64EncodedString()) }
        case is FontFamily.Type: return (value as? FontFamily).map { .text($0.name) }
        case is SBJReferencedContentID.Type: return (value as? SBJReferencedContentID).map { .text($0.rawValue) }
        case is CodableColor.Type:
            guard let color = value as? CodableColor else { return nil }
            return .object(["red": .number(color.red), "green": .number(color.green),
                            "blue": .number(color.blue), "opacity": .number(color.opacity)])
        default: break
        }
        if let integer = value as? any FixedWidthInteger { return integerValue(integer) }
        if let floating = value as? any BinaryFloatingPoint { return .number(Double(floating)) }
        if let named = value as? any SBJEnumCaseIdentifiable { return .text(named.sbjCaseName) }
        // A declared scalar/CaseIterable raw enum exposes its public raw value.
        if (value is any SBJStructuralScalar || value is any CaseIterable),
           let raw = value as? any RawRepresentable {
            let rawValue = raw.rawValue
            let rawType = Swift.type(of: rawValue)
            if rawType != type, rawType == String.self || rawValue is any FixedWidthInteger || rawValue is any BinaryFloatingPoint {
                return self.value(rawValue, type: rawType)
            }
        }
        if let unit = value as? any UnitType { return .text(unit.symbol) }
        return nil
    }

    private static func integerValue<T: FixedWidthInteger>(_ value: T) -> SBJSemanticValue? {
        if T.isSigned { return Int64(exactly: value).map(SBJSemanticValue.signed) ?? .text(String(value)) }
        return UInt64(exactly: value).map(SBJSemanticValue.unsigned) ?? .text(String(value))
    }
}
