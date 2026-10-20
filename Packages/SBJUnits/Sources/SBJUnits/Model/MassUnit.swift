import Foundation
import SBJDataDefinition

@SBJStructure
public enum MassUnit: String, UnitType {
    case gram
    case kilogram
    case ounce
    case pound

    public var foundationUnit: UnitMass {
        switch self {
        case .gram: .grams
        case .kilogram: .kilograms
        case .ounce: .ounces
        case .pound: .pounds
        }
    }

    public var measurementSystem: MeasurementSystem {
        switch self {
        case .gram, .kilogram: .metric
        case .ounce, .pound: .imperial
        }
    }

    public var numberFormat: UnitNumberFormat {
        switch measurementSystem {
        case .imperial: .fraction(fallbackSignificantDigits: 4)
        case .metric, .universal: .decimal(significantDigits: 2)
        }
    }

}
