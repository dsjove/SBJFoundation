import SBJUIVocabulary
import Observation
import SBJDataDefinition
import SBJLocalization

@Observable
@MainActor
public final class UnitConversionModel<Unit: UnitType> {
    public var source: UnitValue<Unit>
    public var destinationUnit: Unit

    public init(source: UnitValue<Unit>, destinationUnit: Unit) {
        self.source = source
        self.destinationUnit = destinationUnit
    }

    public static func propertyInfo<Value>(for keyPath: KeyPath<UnitConversionModel<Unit>, Value>) -> SBJPropertyInfo? {
        switch keyPath as AnyKeyPath {
        case \UnitConversionModel<Unit>.source:
            return SBJPropertyInfo(
                title: "From",
                summary: "Source measurement to convert.",
                details: "Enter a value and choose its source unit.",
                accessibilityLabel: "From value"
            )
        case \UnitConversionModel<Unit>.destinationUnit:
            return SBJPropertyInfo(
                title: "To Unit",
                summary: "Destination unit for the conversion.",
                details: "Changing this unit updates the displayed result.",
                accessibilityLabel: "To unit",
                accessibilityHint: "Chooses the destination unit for the conversion."
            )
        default:
            return nil
        }
    }

    public static var resetPropertyInfo: SBJPropertyInfo {
        SBJPropertyInfo(
            title: "Reset Value",
            summary: "Resets the source value.",
            details: "The standard conversion view resets the source amount to one.",
            accessibilityLabel: "Reset value"
        )
    }

    public static var swapPropertyInfo: SBJPropertyInfo {
        SBJPropertyInfo(
            title: "Swap Units",
            summary: "Swaps the source and destination units.",
            details: "The converted result becomes the new source so the represented quantity does not change.",
            accessibilityLabel: "Swap units"
        )
    }

    public var result: UnitValue<Unit> {
        source.converted(to: destinationUnit)
    }

    public func swap() {
        let oldSourceUnit = source.unit
        source = result
        destinationUnit = oldSourceUnit
    }

    public func step(using policy: UnitEditingPolicy<Unit>, increasing: Bool) {
        source = policy.stepped(source, increasing: increasing)
    }

    public func reset(to value: Double = 1) {
        source.value = value
    }
}
