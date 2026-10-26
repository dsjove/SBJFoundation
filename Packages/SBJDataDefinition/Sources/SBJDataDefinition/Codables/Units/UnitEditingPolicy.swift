import Foundation

/// Editing increments are presentation/application policy, not intrinsic unit
/// semantics. Different apps can therefore step the same physical unit in
/// different increments without changing conversion behavior.
@SBJStructure
public struct UnitEditingPolicy<Unit: UnitType>: Codable, Equatable, Sendable {
    public var defaultStep: Double
    public var overrides: [Unit: Double]

    @SBJDesignatedInit
    public init(defaultStep: Double = 1, overrides: [Unit: Double] = [:]) {
        self.defaultStep = defaultStep
        self.overrides = overrides
    }

    public var hasContent: Bool { true }

    public func stepAmount(for unit: Unit) -> Double {
        overrides[unit] ?? defaultStep
    }

    public func stepped(_ value: UnitValue<Unit>, increasing: Bool) -> UnitValue<Unit> {
        let amount = stepAmount(for: value.unit)
        guard amount.isFinite, amount > 0 else { return value }
        if !increasing, value.value.isZero { return value }
        let newValue: Double
        if increasing {
            newValue = (floor(value.value / amount) + 1) * amount
        } else {
            newValue = (ceil(value.value / amount) - 1) * amount
        }
        return .init(newValue, unit: value.unit)
    }
}
