import Foundation

extension DurationUnit: SBJTextPresentable {
    public var abbreviation: String {
        switch self {
        case .second: "s"
        case .minute: "min"
        case .hour: "hr"
        case .day: "day"
        }
    }
}
