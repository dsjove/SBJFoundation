import CoreGraphics
import Foundation
import SBJLocalization
import SBJDataDefinition


/// Reserved skew state for the portable non-destructive format. Values are degrees.
/// Rendering/editing of non-zero values is intentionally not implemented yet.
@SBJStructure
public struct PhotoSkew: Codable, Equatable, Sendable {
    public var horizontalDegrees: Double
    public var verticalDegrees: Double
    public init(horizontalDegrees: Double = 0, verticalDegrees: Double = 0) { self.horizontalDegrees = horizontalDegrees; self.verticalDegrees = verticalDegrees }
    public static let identity = Self()
    public var isIdentity: Bool { self == .identity }
}
