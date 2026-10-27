import Foundation

extension PairedUnitValue: SBJTextPresentable {
    public var presentedValue: String {
        let firstText = unit.format(value: first)
        let secondText = second.map { " / " + unit.format(value: $0) } ?? ""
        return "\(firstText)\(secondText) \(unit.abbreviation)"
    }
}
