import SBJUIVocabulary
import Foundation
import SBJDataDefinition
import SBJLocalization

@SBJEditable
public enum LengthUnit: String, UnitType {
    case point
    case millimeter
    case centimeter
    case meter
    case kilometer
    case inch
    case foot
    case yard
    case mile

    public var foundationUnit: UnitLength {
        switch self {
        case .point: .sbjPoints
        case .millimeter: .millimeters
        case .centimeter: .centimeters
        case .meter: .meters
        case .kilometer: .kilometers
        case .inch: .inches
        case .foot: .feet
        case .yard: .yards
        case .mile: .miles
        }
    }

    public var measurementSystem: MeasurementSystem {
        switch self {
        case .point: .universal
        case .millimeter, .centimeter, .meter, .kilometer: .metric
        case .inch, .foot, .yard, .mile: .imperial
        }
    }

    public var numberFormat: UnitNumberFormat {
        switch measurementSystem {
        case .imperial: .fraction(fallbackSignificantDigits: 4)
        case .metric, .universal: .decimal(significantDigits: 2)
        }
    }

    public var displayName: String {
        switch self {
        case .point: "Point"
        case .millimeter: "Millimeter"
        case .centimeter: "Centimeter"
        case .meter: "Meter"
        case .kilometer: "Kilometer"
        case .inch: "Inch"
        case .foot: "Foot"
        case .yard: "Yard"
        case .mile: "Mile"
        }
    }
}

@SBJEditable
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

    public var displayName: String {
        switch self {
        case .gram: "Gram"
        case .kilogram: "Kilogram"
        case .ounce: "Ounce"
        case .pound: "Pound"
        }
    }
}

@SBJEditable
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

    public var displayName: String {
        switch self {
        case .milliliter: "Milliliter"
        case .liter: "Liter"
        case .teaspoon: "Teaspoon"
        case .tablespoon: "Tablespoon"
        case .fluidOunce: "Fluid Ounce"
        case .cup: "Cup"
        case .pint: "Pint"
        case .gallon: "Gallon"
        }
    }
}

@SBJEditable
public enum DurationUnit: String, UnitType {
    case second
    case minute
    case hour
    case day

    public var foundationUnit: UnitDuration {
        switch self {
        case .second: .seconds
        case .minute: .minutes
        case .hour: .hours
        case .day: .sbjDays
        }
    }

    public var measurementSystem: MeasurementSystem { .universal }

    public var numberFormat: UnitNumberFormat { .decimal(significantDigits: 4) }

    public var displayName: String {
        switch self {
        case .second: "Second"
        case .minute: "Minute"
        case .hour: "Hour"
        case .day: "Day"
        }
    }
}

public extension UnitLength {
    /// PDF/Core Graphics point: 72 points per inch.
    static let sbjPoints = UnitLength(
        symbol: "pt",
        converter: UnitConverterLinear(coefficient: 0.0254 / 72.0)
    )
}

public extension UnitDuration {
    static let sbjDays = UnitDuration(
        symbol: "day",
        converter: UnitConverterLinear(coefficient: 86_400)
    )
}
