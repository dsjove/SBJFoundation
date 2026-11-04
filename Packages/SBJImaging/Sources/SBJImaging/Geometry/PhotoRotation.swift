import CoreGraphics
import Foundation
import SBJLocalization
import SBJDataDefinition


@SBJStructure
public struct PhotoRotation: Codable, Equatable, Sendable {
    public var quarterTurns: Int = 0
    @SBJNumber(range: -15...15)
    public var fineDegrees: Double = 0

    public init(quarterTurns: Int = 0, fineDegrees: Double = 0) { self.quarterTurns = quarterTurns; self.fineDegrees = fineDegrees }
    public var degrees: Double { Double(((quarterTurns % 4) + 4) % 4) * 90 + fineDegrees }
    public mutating func rotate(clockwise: Bool) { quarterTurns += clockwise ? 1 : -1; quarterTurns = ((quarterTurns % 4) + 4) % 4 }


}
