import Foundation
import SBJDataDefinition

@SBJStructure
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

}
