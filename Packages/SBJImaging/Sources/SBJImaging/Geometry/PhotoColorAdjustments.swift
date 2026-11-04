import CoreGraphics
import Foundation
import SBJLocalization
import SBJDataDefinition


/// Reserved color recipe. Kept as a distinct Codable object so future color controls do not change the document container schema.
@SBJStructure
public struct PhotoColorAdjustments: Codable, Equatable, Sendable {
    public init() {}
}
