import Observation
import SBJDataDefinition

@Observable
public final class UnitConversionModel<Unit: UnitType> {
    public var source: UnitValue<Unit>
    public var destinationUnit: Unit

    public init(source: UnitValue<Unit>, destinationUnit: Unit) {
        self.source = source
        self.destinationUnit = destinationUnit
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
