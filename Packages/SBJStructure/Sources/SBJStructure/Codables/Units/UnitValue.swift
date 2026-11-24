import Foundation

/// Codable pairing of a numeric amount and a strongly typed unit.
///
/// `UnitValue` stores the source unit rather than normalizing values at rest.
/// Conversion is explicit and non-mutating, which preserves the vocabulary of
/// imported/domain data while still using Foundation `Measurement` for math.
@SBJStructure
public struct UnitValue<U: UnitType>: Codable, Equatable, Sendable, Hashable {
	public typealias Unit = U
    public var value: Double
    public let unit: Unit

    @SBJDesignatedInit
    public init(_ value: Double = 0, unit: Unit) {
        self.value = value
        self.unit = unit
    }

    public func converted(to otherUnit: Unit) -> Self {
        .init(unit.convert(value, to: otherUnit), unit: otherUnit)
    }

    public var hasContent: Bool { !value.isZero }

    // The containing @SBJStructure type enforces its @SBJUnitValue constraints.
    // This intrinsic invariant only enforces that a numeric quantity is finite.
    public func invariant(at keyPath: SBJValidationKeyPath) throws {
        try _invariant(at: keyPath)
        try SBJInvariantCheck.require(value.isFinite, at: keyPath,
                                      "measurement value must be finite")
    }
}
