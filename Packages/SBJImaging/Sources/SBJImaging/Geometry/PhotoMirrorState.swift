import CoreGraphics
import Foundation
import SBJLocalization
import SBJDataDefinition


@SBJStructure
public struct PhotoMirrorState: Codable, Equatable, Sendable {
    public var horizontal = false
    public var vertical = false
    public init(horizontal: Bool = false, vertical: Bool = false) { self.horizontal = horizontal; self.vertical = vertical }
    public mutating func toggle(_ axis: PhotoMirrorAxis) { switch axis { case .horizontal: horizontal.toggle(); case .vertical: vertical.toggle() } }

}
