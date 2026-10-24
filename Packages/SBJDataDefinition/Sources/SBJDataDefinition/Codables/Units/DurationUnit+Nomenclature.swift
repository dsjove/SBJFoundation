import Foundation

extension DurationUnit: StringPresentable {
    public var abbreviation: String {
        switch self {
        case .second: "s"
        case .minute: "min"
        case .hour: "hr"
        case .day: "day"
        }
    }
}
