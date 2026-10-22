import Foundation
import UniformTypeIdentifiers
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(PencilKit)
import PencilKit
#endif
import SBJDataDefinition
import SBJUIVocabulary


@SBJStructure
public enum PhotoMarkupCoordinateSpace: String, Codable, Equatable, Sendable {
    /// Markup coordinates describe the visible composition/crop frame, not source pixels.
    case composition
}
