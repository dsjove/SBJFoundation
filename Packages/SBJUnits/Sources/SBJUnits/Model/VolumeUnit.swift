import Foundation
import SBJDataDefinition
import SBJLocalization

@SBJStructure
public enum VolumeUnit: String, UnitType {
    case milliliter
    case liter
    case teaspoon
    case tablespoon
    case fluidOunce
    case cup
    case pint
    case gallon

    public var foundationUnit: UnitVolume {
        switch self {
        case .milliliter: .milliliters
        case .liter: .liters
        case .teaspoon: .teaspoons
        case .tablespoon: .tablespoons
        case .fluidOunce: .fluidOunces
        case .cup: .cups
        case .pint: .pints
        case .gallon: .gallons
        }
    }

    public var measurementSystem: MeasurementSystem {
        switch self {
        case .milliliter, .liter: .metric
        default: .imperial
        }
    }

    public var numberFormat: UnitNumberFormat {
        switch measurementSystem {
        case .imperial: .fraction(fallbackSignificantDigits: 4)
        case .metric, .universal: .decimal(significantDigits: 2)
        }
    }
}
