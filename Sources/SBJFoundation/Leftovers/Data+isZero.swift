import Foundation
import SBJUIVocabulary

import SBJDataDefinition
public extension Data {
    var isZero: Bool {
        isEmpty || allSatisfy { $0 == .zero }
    }
}
