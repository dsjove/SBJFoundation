import Foundation

/// An explicitly mixed measurement (for example 5 ft 9 in).
///
/// The major and minor units are stored rather than inferred. Conversion to a
/// single `UnitValue` is explicit. This type deliberately does not normalize
/// values automatically: some domains use signed components or noncanonical
/// input, and Codable must preserve the values the user entered.
@SBJStructure
public struct MixedUnitValue<U: UnitType>: Codable, Equatable, Hashable, Sendable {
	public typealias Unit = U
    public var major: UnitValue<Unit>
    public var minor: UnitValue<Unit>

    @SBJDesignatedInit
    public init(major: UnitValue<Unit>, minor: UnitValue<Unit>) {
        self.major = major
        self.minor = minor
    }

    public init(_ value: Double = 0, unit: Unit) {
        self.major = .init(value, unit: unit)
        self.minor = .init(0, unit: unit)
    }

    /// Total physical measurement expressed in the requested unit.
    public func converted(to unit: Unit) -> UnitValue<Unit> {
        UnitValue(
            major.unit.convert(major.value, to: unit)
                + minor.unit.convert(minor.value, to: unit),
            unit: unit
        )
    }

    public var hasContent: Bool { major.hasContent || minor.hasContent }

    public func invariant(at keyPath: SBJValidationKeyPath) throws {
        try _invariant(at: keyPath)
        try SBJInvariantCheck.require(
            major.value.isFinite && minor.value.isFinite,
            at: keyPath,
            "mixed measurement components must be finite"
        )
    }
}
