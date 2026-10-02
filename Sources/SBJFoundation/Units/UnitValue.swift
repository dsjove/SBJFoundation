import Foundation

/// Codable pairing of a numeric amount and a strongly typed unit.
///
/// `UnitValue` stores the source unit rather than normalizing values at rest.
/// Conversion is explicit and non-mutating, which preserves the vocabulary of
/// imported/domain data while still using Foundation `Measurement` for math.
@SBJStructure
public struct UnitValue<Unit: UnitType>: SBJFoundationType, Sendable, Hashable {
    public var value: Double
    public var unit: Unit

    @SBJDesignatedInit
    public init(_ value: Double = 0, unit: Unit) {
        self.value = value
        self.unit = unit
    }

    /// Compatibility initializer for the former Character `Quantity` spelling.
    public init(_ value: Double = 0, _ unit: Unit) {
        self.init(value, unit: unit)
    }

    /// Compatibility bridge while existing applications migrate from `kind`.
    /// New code should use `unit`.
    public var kind: Unit {
        get { unit }
        set { unit = newValue }
    }

    public func converted(to otherUnit: Unit) -> Self {
        .init(unit.convert(value, to: otherUnit), unit: otherUnit)
    }

    public var hasContent: Bool { !value.isZero }

    public static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
        switch keyPath as AnyKeyPath {
        case \Self.value:
            return SBJPropertyInfo(
                title: "Value",
                summary: "Numeric amount expressed in the selected unit.",
                details: "Changing the unit through UnitValueControl converts this number so the represented physical quantity is preserved.",
                accessibilityLabel: "Value"
            )
        case \Self.unit:
            return SBJPropertyInfo(
                title: "Unit",
                summary: "Measurement unit used by this value.",
                details: "Selecting another unit converts the numeric amount rather than reinterpreting it.",
                accessibilityLabel: "Unit",
                accessibilityHint: "Changes the unit while preserving the represented quantity."
            )
        default:
            return nil
        }
    }

    public func invariant(at keyPath: SBJValidationKeyPath) throws {
        try SBJInvariantCheck.require(
            value.isFinite,
            at: keyPath,
            "measurement value must be finite"
        )
    }

    private enum CodingKeys: String, CodingKey {
        case value
        case unit
        case kind // legacy Character `Quantity` key
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decode(Double.self, forKey: .value)
        if let decoded = try container.decodeIfPresent(Unit.self, forKey: .unit) {
            unit = decoded
        } else {
            unit = try container.decode(Unit.self, forKey: .kind)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(unit, forKey: .unit)
    }
}

/// Source-compatibility name used by applications that previously owned their
/// own generic quantity type. New shared code should prefer `UnitValue`.
public typealias Quantity<Unit: UnitType> = UnitValue<Unit>
