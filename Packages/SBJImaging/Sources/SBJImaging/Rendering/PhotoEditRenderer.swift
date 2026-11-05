#if !os(watchOS) && (canImport(UIKit) || canImport(AppKit))
import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import SBJLocalization
import SBJFileResources
import SBJDataDefinition
import SBJUIVocabulary
#if canImport(UIKit) && canImport(PencilKit)
import UIKit
import PencilKit
#endif

/// Shared non-destructive raster renderer. Native image conversions are limited
/// to the image boundary; drawing and encoding use CoreGraphics and ImageIO.
enum PhotoEditRenderer {
    enum Encoding {
        case sourceCompatible
        case thumbnail
    }

    static func render(
        resource: SBJResourceContent,
        geometry: PhotoEditGeometry,
        color: PhotoColorAdjustments = .init(),
        options: PhotoEditorOptions,
        markup: Any? = nil,
        markupCanvasSize: CGSize = .zero,
        maximumPixelDimension: CGFloat? = nil,
        encoding: Encoding = .sourceCompatible
    ) -> SBJResourceContent? {
        let storedMarkup = markup as? PhotoMarkup
        #if canImport(UIKit) && canImport(PencilKit)
        let drawing: PKDrawing? = (markup as? PKDrawing) ?? storedMarkup?.pencilKitDrawing
        // A serialized format we cannot decode must never be silently omitted.
        if storedMarkup != nil, drawing == nil { return nil }
        #else
        // Never render an unmarked derivative over a document carrying markup
        // this platform does not support. Existing caches remain intact.
        guard storedMarkup == nil, markup == nil else { return nil }
        #endif

        // CIImage applies container orientation (including EXIF) before any
        // geometry is resolved. This is important for rotated phone photos.
        guard let input = CIImage(data: resource.data, options: [
            .applyOrientationProperty: true
        ]) else { return nil }
        let ciContext = CIContext()
        let oriented = color.applying(to: input)
        let extent = oriented.extent.integral
        guard extent.width > 0, extent.height > 0,
              let source = ciContext.createCGImage(oriented, from: extent) else {
            return nil
        }
        let sourceSize = CGSize(width: CGFloat(source.width), height: CGFloat(source.height))
        let natural = outputPixelSize(sourceSize: sourceSize, geometry: geometry)
        guard natural.width >= 1, natural.height >= 1 else { return nil }
        let size = bounded(natural, maximumPixelDimension: maximumPixelDimension)
        let layout = PhotoGeometryResolver.resolve(
            sourceSize: sourceSize, containerSize: size,
            geometry: geometry, options: options, frameInset: 0
        )
        let width = Int(ceil(size.width))
        let height = Int(ceil(size.height))
        guard width > 0, height > 0 else { return nil }
        let alpha = hasAlpha(source)
        let info = alpha ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast
        // The output bitmap is RGBA regardless of the source's native space.
        // CoreGraphics does not support all source spaces with an 8-bit RGBA
        // bitmap context (e.g. grayscale/CMYK).
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: info.rawValue
        ) else { return nil }
        // PhotoGeometryResolver uses UIKit-style, top-left geometry on both
        // platforms; normalize once at the beginning of the drawing pass.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.saveGState()
        if geometry.crop.option != .none {
            context.clip(to: layout.frameRect)
        }
        context.concatenate(layout.sourceToFrameTransform)
        // CGImage draws in native bottom-left coordinates; flip locally so
        // its orientation matches the shared top-left geometry convention.
        context.translateBy(x: 0, y: sourceSize.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(source, in: CGRect(origin: .zero, size: sourceSize))
        context.restoreGState()

        #if canImport(UIKit) && canImport(PencilKit)
        if let drawing, !drawing.bounds.isEmpty,
           markupCanvasSize.width > 0, markupCanvasSize.height > 0 {
            let raster = drawing.image(
                from: CGRect(origin: .zero, size: markupCanvasSize),
                scale: max(size.width / markupCanvasSize.width,
                           size.height / markupCanvasSize.height)
            )
            if let cg = raster.cgImage {
                context.saveGState()
                context.translateBy(x: layout.frameRect.minX,
                                    y: layout.frameRect.maxY)
                context.scaleBy(x: 1, y: -1)
                context.draw(cg, in: CGRect(origin: .zero,
                                           size: layout.frameRect.size))
                context.restoreGState()
            }
        }
        #endif
        guard let output = context.makeImage() else { return nil }
        return encode(output, preferred: resource.contentType, encoding: encoding)
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

    private static func encode(_ image: CGImage, preferred: UTType, encoding: Encoding) -> SBJResourceContent? {
        let format: UTType
        let quality: Double
        switch encoding {
        case .thumbnail:
            format = hasAlpha(image) ? .png : .jpeg
            quality = 0.82
        case .sourceCompatible:
            format = preferred.conforms(to: .png) || hasAlpha(image) ? .png : .jpeg
            quality = 0.95
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, format.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: quality
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return SBJResourceContent(data: data as Data, contentType: format)
    }

    private static func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }
}
#endif
