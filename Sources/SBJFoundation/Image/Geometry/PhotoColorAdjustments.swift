import SBJDataDefinition
import CoreGraphics
import Foundation
import SBJLocalization


/// Reserved color recipe. Kept as a distinct Codable object so future color controls do not change the document container schema.
@SBJStructure
public struct PhotoColorAdjustments: Codable, Equatable, Sendable {
    public init() {}
}
