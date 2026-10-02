import Foundation

/// Editing increments are presentation/application policy, not intrinsic unit
/// semantics. Different apps can therefore step the same physical unit in
/// different increments without changing conversion behavior.
@SBJStructure
public struct UnitEditingPolicy<Unit: UnitType>: SBJFoundationType, Sendable {
    public var defaultStep: Double
    public var overrides: [Unit: Double]

    public init(defaultStep: Double, overrides: [Unit: Double] = [:]) {
        self.defaultStep = defaultStep
        self.overrides = overrides
    }

    public static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
        switch keyPath as AnyKeyPath {
        case \Self.defaultStep:
            return SBJPropertyInfo(
                title: "Default Step",
                summary: "Default increment used when stepping a unit value.",
                details: "Per-unit overrides take precedence. Non-finite or non-positive steps are ignored."
            )
        case \Self.overrides:
            return SBJPropertyInfo(
                title: "Unit Step Overrides",
                summary: "Per-unit editing increments.",
                details: "Each entry replaces the default step for that unit."
            )
        default:
            return nil
        }
    }

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
