import SBJDataDefinition
import CoreGraphics
import Foundation
import SBJLocalization


@SBJStructure
public enum PhotoFramingConstraint: Codable, Equatable, Sendable, Hashable {
    /// The transformed image must cover the complete crop/output rectangle.
    case cover
    /// The transformed image may expose frame background, but may not become
    /// completely contained inside the visual frame.
    case overlap
    /// No framing constraint is imposed by the editor.
    case none
}
