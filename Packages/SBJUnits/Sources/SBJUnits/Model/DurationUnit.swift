import Foundation
import SBJDataDefinition

@SBJStructure
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

    public var numberFormat: SBJNumberFormatStyle { .decimal(significantDigits: 4) }

}
