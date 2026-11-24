import Foundation

extension MixedUnitValue: SBJTextPresentable {
    public var presentedValue: String {
        "\(major.presentedValue) \(major.presentedValue)"
    }
}
