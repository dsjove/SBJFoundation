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
public struct PhotoMarkupCanvasSize: Codable, Equatable, Sendable {
    @SBJNumber(min: 0)
    public var width: Double
    @SBJNumber(min: 0)
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public init(_ size: CGSize) {
        self.init(width: size.width, height: size.height)
    }

    public var cgSize: CGSize { .init(width: width, height: height) }
}
