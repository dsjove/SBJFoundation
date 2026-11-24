import Foundation

/// Unit-specific validation belongs with the unit abstraction rather than in
/// SBJStructure's general invariant checker implementation.
public extension SBJInvariantCheck {
    /// Enforces an explicitly locked measurement unit declared by @SBJUnitValue.
    static func requireUnit<U: UnitType>(
        _ value: UnitValue<U>, _ expected: U, at keyPath: SBJValidationKeyPath
    ) throws {
        guard value.unit == expected else {
            throw SBJValidationError(
                value.unit,
                at: keyPath,
                "unit must equal the declared fixed unit"
            )
        }
    }

    static func requireUnit<U: UnitType>(
        _ value: UnitValue<U>?, _ expected: U, at keyPath: SBJValidationKeyPath
    ) throws {
        if let value { try requireUnit(value, expected, at: keyPath) }
    }

    static func requireMinimum<Unit: UnitType>(
        _ value: UnitValue<Unit>,
        _ minimum: Double,
        at keyPath: SBJValidationKeyPath
    ) throws {
        guard value.value >= minimum else {
            throw SBJValidationError(
                value.value,
                at: keyPath,
                "must be at least \(minimum)"
            )
        }
    }

    static func requireMinimum<Unit: UnitType>(
        _ value: UnitValue<Unit>?,
        _ minimum: Double,
        at keyPath: SBJValidationKeyPath
    ) throws {
        if let value { try requireMinimum(value, minimum, at: keyPath) }
    }
}
