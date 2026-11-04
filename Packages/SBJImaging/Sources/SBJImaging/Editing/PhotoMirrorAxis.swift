import CoreGraphics
import Foundation
import SBJLocalization
import SBJDataDefinition


@SBJStructure
public enum PhotoMirrorAxis: String, Codable, Equatable, Sendable, Hashable {
    case horizontal
    case vertical
}
