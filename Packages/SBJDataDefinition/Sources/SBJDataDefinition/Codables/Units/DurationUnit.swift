import Foundation

@SBJStructure
public enum DurationUnit: String, UnitType {
    case milliseconds
    case second
    case minute
    case hour
    case day

    public var foundationUnit: UnitDuration {
        switch self {
        case .milliseconds: .milliseconds
        case .second: .seconds
        case .minute: .minutes
        case .hour: .hours
        case .day: .sbjDays
        }
    }

    public var measurementSystem: MeasurementSystem { .universal }

    public var numberFormat: SBJNumberFormatStyle { .decimal(significantDigits: 4) }
}

/// A stable order enables ClosedRange<DurationUnit> in annotations and formatting.
/// Codable raw strings remain unchanged for existing persisted units.
extension DurationUnit: Comparable {
    public static func < (lhs: DurationUnit, rhs: DurationUnit) -> Bool {
        lhs.rank < rhs.rank
    }

    public var rank: Int {
        switch self {
        case .milliseconds: 0
        case .second: 1
        case .minute: 2
        case .hour: 3
        case .day: 4
        }
    }

    public var seconds: TimeInterval {
        switch self {
        case .milliseconds: 0.001
        case .second: 1
        case .minute: 60
        case .hour: 3600
        case .day: 86_400
        }
    }

    public static var ordered: [DurationUnit] {
        [.milliseconds, .second, .minute, .hour, .day]
    }
}
