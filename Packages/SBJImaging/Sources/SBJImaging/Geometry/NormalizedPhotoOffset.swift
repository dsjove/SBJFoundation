import CoreGraphics
import Foundation
import SBJLocalization
import SBJDataDefinition


@SBJStructure
public struct NormalizedPhotoOffset: Codable, Equatable, Sendable {
    public var x: Double = 0
    public var y: Double = 0

    public init(x: Double = 0, y: Double = 0) { self.x = x; self.y = y }
    public static let zero = Self()


}
