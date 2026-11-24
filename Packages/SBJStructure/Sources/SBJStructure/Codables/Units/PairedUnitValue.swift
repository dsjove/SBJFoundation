import Foundation

/// Two independent numeric quantities expressed in one shared unit.
/// Unlike MixedUnitValue, these values are not added together.
@SBJStructure
public struct PairedUnitValue<U: UnitType>: Codable, Equatable, Hashable, Sendable {
    public typealias Unit = U
    public var first: Double
    public var second: Double?
    public let unit: Unit

    @SBJDesignatedInit
    public init(_ first: Double = 0, _ second: Double? = nil, unit: Unit) {
        self.first = first
        self.second = second
        self.unit = unit
    }

    public func converted(to target: Unit) -> Self {
        .init(unit.convert(first, to: target),
              second.map { unit.convert($0, to: target) }, unit: target)
    }

    public var hasContent: Bool { !first.isZero || second != nil }

    public func invariant(at keyPath: SBJValidationKeyPath) throws {
        try _invariant(at: keyPath)
        try SBJInvariantCheck.require(first.isFinite && (second?.isFinite ?? true),
                                      at: keyPath, "paired measurement values must be finite")
    }
}
