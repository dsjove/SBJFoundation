import Foundation

public extension Data {
    var isZero: Bool {
        isEmpty || allSatisfy { $0 == .zero }
    }
}
