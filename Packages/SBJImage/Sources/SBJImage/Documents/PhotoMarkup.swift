import SBJDataDefinition
import Foundation
import UniformTypeIdentifiers
import CoreGraphics
#if canImport(PencilKit)
import PencilKit
#endif
import SBJUIVocabulary

@SBJStructure
public struct PhotoMarkup: Codable, Equatable, Sendable {
    public var data: Data
    public var contentTypeIdentifier: String
    public var canvasSize: PhotoMarkupCanvasSize
    public var coordinateSpace: PhotoMarkupCoordinateSpace

    public init(
        data: Data,
        contentType: UTType,
        canvasSize: PhotoMarkupCanvasSize,
        coordinateSpace: PhotoMarkupCoordinateSpace = .composition
    ) {
        self.init(
            data: data,
            contentTypeIdentifier: contentType.identifier,
            canvasSize: canvasSize,
            coordinateSpace: coordinateSpace
        )
    }

    /// Creates markup without requiring its content type to be registered with
    /// Launch Services. Image-document packages must be able to round-trip
    /// private or otherwise unknown markup encodings by identifier alone.
    public init(
        data: Data,
        contentTypeIdentifier: String,
        canvasSize: PhotoMarkupCanvasSize,
        coordinateSpace: PhotoMarkupCoordinateSpace = .composition
    ) {
        self.data = data
        self.contentTypeIdentifier = contentTypeIdentifier
        self.canvasSize = canvasSize
        self.coordinateSpace = coordinateSpace
    }

    public var contentType: UTType? { UTType(contentTypeIdentifier) }
}


#if canImport(PencilKit)
public extension PhotoMarkup {
    static let pencilKitContentTypeIdentifier = "com.softwarebyjove.pencilkit-drawing"

    init(
        drawing: PKDrawing,
        canvasSize: CGSize,
        coordinateSpace: PhotoMarkupCoordinateSpace = .composition
    ) {
        self.init(
            data: drawing.dataRepresentation(),
            contentTypeIdentifier: Self.pencilKitContentTypeIdentifier,
            canvasSize: .init(canvasSize),
            coordinateSpace: coordinateSpace
        )
    }

    var pencilKitDrawing: PKDrawing? { try? PKDrawing(data: data) }
}
#endif
