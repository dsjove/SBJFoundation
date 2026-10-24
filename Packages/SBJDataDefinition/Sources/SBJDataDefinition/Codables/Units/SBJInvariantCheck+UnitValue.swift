/// Unit-specific validation belongs with the unit abstraction rather than in
/// SBJStructure's general invariant checker implementation.
public extension SBJInvariantCheck {
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
