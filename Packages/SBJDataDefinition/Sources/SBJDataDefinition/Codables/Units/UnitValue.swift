import Foundation

/// Codable pairing of a numeric amount and a strongly typed unit.
///
/// `UnitValue` stores the source unit rather than normalizing values at rest.
/// Conversion is explicit and non-mutating, which preserves the vocabulary of
/// imported/domain data while still using Foundation `Measurement` for math.
public struct UnitValue<Unit: UnitType>: Codable, Equatable, Sendable, Hashable {
    public var value: Double
    public let unit: Unit

    public init(_ value: Double = 0, unit: Unit) {
        self.value = value
        self.unit = unit
    }

    public init(_ value: Double = 0, _ unit: Unit) {
        self.value = value
        self.unit = unit
    }

    public func converted(to otherUnit: Unit) -> Self {
        .init(unit.convert(value, to: otherUnit), unit: otherUnit)
    }

    public var hasContent: Bool { !value.isZero }

}
