import Foundation
import UniformTypeIdentifiers
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(PencilKit)
import PencilKit
#endif

public struct PhotoMarkupCanvasSize: SBJFoundationType, Sendable {
    public var width: Double
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

public enum PhotoMarkupCoordinateSpace: String, SBJFoundationType, Sendable {
    /// Markup coordinates describe the visible composition/crop frame, not source pixels.
    case composition
}


/// Format-neutral serialized markup. PencilKit is one supported encoding, not part of the container contract.
public struct PhotoMarkup: SBJFoundationType, Sendable {
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
