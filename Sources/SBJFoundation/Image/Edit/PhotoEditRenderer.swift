#if !os(watchOS) && canImport(UIKit)
import ImageIO
import SBJDataDefinition
import SBJFileResources
import UniformTypeIdentifiers
import UIKit
#if canImport(PencilKit)
import PencilKit
#endif

enum PhotoEditRenderer {
    enum Encoding {
        case sourceCompatible
        case thumbnail
    }

    static func render(
        resource: SBJResourceContent,
        geometry: PhotoEditGeometry,
        options: PhotoEditorOptions,
        markup: Any? = nil,
        markupCanvasSize: CGSize = .zero,
        maximumPixelDimension: CGFloat? = nil,
        encoding: Encoding = .sourceCompatible
    ) -> SBJResourceContent? {
        guard let source = resource.uiImage else { return nil }
        let sourceSize = source.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

        let naturalOutputSize = outputPixelSize(sourceSize: sourceSize, geometry: geometry)
        guard naturalOutputSize.width >= 1, naturalOutputSize.height >= 1 else { return nil }

        let outputSize = bounded(
            naturalOutputSize,
            maximumPixelDimension: maximumPixelDimension
        )
        let layout = PhotoGeometryResolver.resolve(
            sourceSize: sourceSize,
            containerSize: outputSize,
            geometry: geometry,
            options: options,
            frameInset: 0
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !hasAlpha(source)
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        let rendered = renderer.image { context in
            let cg = context.cgContext
            cg.saveGState()
            if geometry.crop.option != .none {
                cg.clip(to: layout.frameRect)
            }
            cg.concatenate(layout.sourceToFrameTransform)
            source.draw(in: CGRect(origin: .zero, size: sourceSize))
            cg.restoreGState()

#if canImport(PencilKit)
            if let drawing = markup as? PKDrawing,
               !drawing.bounds.isEmpty,
               markupCanvasSize.width > 0,
               markupCanvasSize.height > 0 {
                let markupImage = drawing.image(
                    from: CGRect(origin: .zero, size: markupCanvasSize),
                    scale: max(
                        outputSize.width / markupCanvasSize.width,
                        outputSize.height / markupCanvasSize.height
                    )
                )
                markupImage.draw(in: layout.frameRect)
            }
#endif
        }

        return encode(rendered, preferred: resource.contentType, encoding: encoding)
    }

    private static func bounded(
        _ size: CGSize,
        maximumPixelDimension: CGFloat?
    ) -> CGSize {
        guard let maximumPixelDimension,
              maximumPixelDimension > 0 else {
            return size
        }

        let largestDimension = max(size.width, size.height)
        guard largestDimension > maximumPixelDimension else { return size }

        let scale = maximumPixelDimension / largestDimension
        return CGSize(
            width: max(1, floor(size.width * scale)),
            height: max(1, floor(size.height * scale))
        )
    }

    private static func outputPixelSize(
        sourceSize: CGSize,
        geometry: PhotoEditGeometry
    ) -> CGSize {
        let radians = CGFloat(geometry.rotation.degrees * .pi / 180)
        if geometry.crop.option == .none {
            let c = abs(cos(radians))
            let s = abs(sin(radians))
            return CGSize(
                width: ceil(c * sourceSize.width + s * sourceSize.height),
                height: ceil(s * sourceSize.width + c * sourceSize.height)
            )
        }

        let logicalSource = PhotoGeometryResolver.logicalSourceSize(
            sourceSize,
            quarterTurns: geometry.rotation.quarterTurns
        )
        let ratio = geometry.crop.option.aspectRatio(
            sourceSize: logicalSource,
            freeAspectRatio: geometry.crop.freeAspectRatio,
            swappingDimensions: geometry.crop.swapsDimensions
        )
        let sourceRatio = logicalSource.width / logicalSource.height
        if sourceRatio > ratio {
            return CGSize(
                width: logicalSource.height * ratio,
                height: logicalSource.height
            )
        } else {
            return CGSize(
                width: logicalSource.width,
                height: logicalSource.width / ratio
            )
        }
    }

    private static func encode(
        _ image: UIImage,
        preferred: UTType,
        encoding: Encoding
    ) -> SBJResourceContent? {
        switch encoding {
        case .thumbnail:
            if hasAlpha(image), let data = image.pngData() {
                return .init(data: data, contentType: .png)
            }
            if let data = image.jpegData(compressionQuality: 0.82) {
                return .init(data: data, contentType: .jpeg)
            }

        case .sourceCompatible:
            if preferred.conforms(to: .png), let data = image.pngData() {
                return .init(data: data, contentType: .png)
            }
            if preferred.conforms(to: .jpeg),
               let data = image.jpegData(compressionQuality: 0.95) {
                return .init(data: data, contentType: .jpeg)
            }
            if hasAlpha(image), let data = image.pngData() {
                return .init(data: data, contentType: .png)
            }
            if let data = image.jpegData(compressionQuality: 0.95) {
                return .init(data: data, contentType: .jpeg)
            }
        }

        if let data = image.pngData() {
            return .init(data: data, contentType: .png)
        }
        return nil
    }

    private static func hasAlpha(_ image: UIImage) -> Bool {
        guard let alpha = image.cgImage?.alphaInfo else { return false }
        switch alpha {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }
}
#endif
