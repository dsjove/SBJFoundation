import SBJDataDefinition
import CoreGraphics
import Foundation
import SBJLocalization


/// Reserved perspective state for the portable non-destructive format.
/// Identity is the unit square. Rendering/editing of non-identity values is intentionally not implemented yet.
@SBJStructure
public struct PhotoPerspective: Codable, Equatable, Sendable {
    public struct Point: Codable, Equatable, Sendable { public var x: Double; public var y: Double; public init(x: Double, y: Double) { self.x = x; self.y = y } }
    public var topLeft: Point; public var topRight: Point; public var bottomLeft: Point; public var bottomRight: Point
    public init(topLeft: Point = .init(x: 0, y: 0), topRight: Point = .init(x: 1, y: 0), bottomLeft: Point = .init(x: 0, y: 1), bottomRight: Point = .init(x: 1, y: 1)) { self.topLeft = topLeft; self.topRight = topRight; self.bottomLeft = bottomLeft; self.bottomRight = bottomRight }
    public static let identity = Self()
    public var isIdentity: Bool { self == .identity }
}
