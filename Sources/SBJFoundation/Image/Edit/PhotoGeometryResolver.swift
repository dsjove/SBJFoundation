import SBJUIVocabulary
#if !os(watchOS) && canImport(UIKit)
import CoreGraphics
import SBJDataDefinition
import Foundation

struct PhotoResolvedLayout {
    let sourceSize: CGSize
    let frameRect: CGRect
    let baseFittedSize: CGSize
    let renderedImageSize: CGSize
    let translation: CGSize
    let rotationRadians: CGFloat
    let mirrorX: CGFloat
    let mirrorY: CGFloat
    let minimumScale: CGFloat

    var imageCenter: CGPoint {
        CGPoint(x: frameRect.midX + translation.width, y: frameRect.midY + translation.height)
    }

    /// Image center expressed in the crop/frame's local coordinate space.
    /// Keeping this explicit avoids relying on independent SwiftUI layout
    /// containers to infer the same center for the clipped and unclipped image.
    var imageCenterInFrame: CGPoint {
        CGPoint(
            x: frameRect.width / 2 + translation.width,
            y: frameRect.height / 2 + translation.height
        )
    }

    var sourceToFrameTransform: CGAffineTransform {
        var transform = CGAffineTransform(translationX: imageCenter.x, y: imageCenter.y)
        transform = transform.rotated(by: rotationRadians)
        transform = transform.scaledBy(x: mirrorX, y: mirrorY)
        transform = transform.scaledBy(
            x: renderedImageSize.width / sourceSize.width,
            y: renderedImageSize.height / sourceSize.height
        )
        transform = transform.translatedBy(x: -sourceSize.width / 2, y: -sourceSize.height / 2)
        return transform
    }
}

enum PhotoGeometryResolver {
    static func resolve(
        sourceSize: CGSize,
        containerSize: CGSize,
        geometry: PhotoEditGeometry,
        options: PhotoEditorOptions,
        frameInset: CGFloat = 20
    ) -> PhotoResolvedLayout {
        let safeContainer = CGSize(width: max(1, containerSize.width), height: max(1, containerSize.height))
        let cropSourceSize = logicalSourceSize(sourceSize, quarterTurns: geometry.rotation.quarterTurns)
        let frameRect = cropFrame(
            sourceSize: cropSourceSize,
            containerSize: safeContainer,
            crop: geometry.crop,
            inset: frameInset
        )
        let radians = CGFloat(geometry.rotation.degrees * .pi / 180)
        let baseSize: CGSize
        if geometry.crop.option == .none {
            let rotated = rotatedBoundingSize(sourceSize, radians: radians)
            let fit = min(frameRect.width / rotated.width, frameRect.height / rotated.height)
            baseSize = CGSize(width: sourceSize.width * fit, height: sourceSize.height * fit)
        } else {
            baseSize = aspectFit(sourceSize, in: frameRect.size)
        }
        let effectiveConstraint = geometry.crop.option == .none ? options.framingConstraint : .cover

        let minimum = minimumScale(
            imageSize: baseSize,
            frameSize: frameRect.size,
            radians: radians,
            constraint: effectiveConstraint
        )
        let userScale = CGFloat(min(max(geometry.magnification, 1), options.maximumMagnification))
        let renderedSize = CGSize(
            width: baseSize.width * minimum * userScale,
            height: baseSize.height * minimum * userScale
        )

        var translation = CGSize(
            width: CGFloat(geometry.placement.x) * renderedSize.width,
            height: CGFloat(geometry.placement.y) * renderedSize.height
        )
        translation = constrainedTranslation(
            translation,
            imageSize: renderedSize,
            frameSize: frameRect.size,
            radians: radians,
            constraint: effectiveConstraint,
            allowsNone: options.allowsNoneFraming
        )

        return PhotoResolvedLayout(
            sourceSize: sourceSize,
            frameRect: frameRect,
            baseFittedSize: baseSize,
            renderedImageSize: renderedSize,
            translation: translation,
            rotationRadians: radians,
            mirrorX: geometry.mirror.horizontal ? -1 : 1,
            mirrorY: geometry.mirror.vertical ? -1 : 1,
            minimumScale: minimum
        )
    }

    static func normalizedPlacement(
        for translation: CGSize,
        renderedImageSize: CGSize
    ) -> NormalizedPhotoOffset {
        guard renderedImageSize.width > 0, renderedImageSize.height > 0 else { return .zero }
        return .init(
            x: min(max(Double(translation.width / renderedImageSize.width), -1), 1),
            y: min(max(Double(translation.height / renderedImageSize.height), -1), 1)
        )
    }

    static func cropFrame(
        sourceSize: CGSize,
        containerSize: CGSize,
        crop: PhotoCropState,
        inset: CGFloat = 20
    ) -> CGRect {
        let margin = max(0, inset)
        let available = CGSize(
            width: max(1, containerSize.width - margin * 2),
            height: max(1, containerSize.height - margin * 2)
        )
        if crop.option == .none {
            return CGRect(
                x: margin,
                y: margin,
                width: available.width,
                height: available.height
            )
        }

        let ratio = max(
            0.1,
            crop.option.aspectRatio(
                sourceSize: sourceSize,
                freeAspectRatio: crop.freeAspectRatio,
                swappingDimensions: crop.swapsDimensions
            )
        )
        let size: CGSize
        if available.width / available.height > ratio {
            size = CGSize(width: available.height * ratio, height: available.height)
        } else {
            size = CGSize(width: available.width, height: available.width / ratio)
        }
        return CGRect(
            x: (containerSize.width - size.width) / 2,
            y: (containerSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    static func logicalSourceSize(_ source: CGSize, quarterTurns: Int) -> CGSize {
        let turns = ((quarterTurns % 4) + 4) % 4
        return turns % 2 == 0 ? source : CGSize(width: source.height, height: source.width)
    }

    private static func aspectFit(_ source: CGSize, in target: CGSize) -> CGSize {
        guard source.width > 0, source.height > 0 else { return .zero }
        let scale = min(target.width / source.width, target.height / source.height)
        return CGSize(width: source.width * scale, height: source.height * scale)
    }

    /// Minimum scale for a centered image. For cover, this uses the inverse
    /// rotation of the crop corners rather than a bounding-box approximation,
    /// so arbitrary rotation cannot expose a crop corner.
    private static func minimumScale(
        imageSize: CGSize,
        frameSize: CGSize,
        radians: CGFloat,
        constraint: PhotoFramingConstraint
    ) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 1 }
        switch constraint {
        case .none:
            return 1
        case .overlap:
            // Aspect-fit is the natural baseline. A tiny epsilon prevents the
            // image becoming strictly contained on both axes after rounding.
            return 1.0001
        case .cover:
            let c = abs(cos(radians))
            let s = abs(sin(radians))
            let halfFrameW = frameSize.width / 2
            let halfFrameH = frameSize.height / 2
            let requiredLocalX = c * halfFrameW + s * halfFrameH
            let requiredLocalY = s * halfFrameW + c * halfFrameH
            let halfImageW = imageSize.width / 2
            let halfImageH = imageSize.height / 2
            return max(1, requiredLocalX / halfImageW, requiredLocalY / halfImageH)
        }
    }

    private static func constrainedTranslation(
        _ proposed: CGSize,
        imageSize: CGSize,
        frameSize: CGSize,
        radians: CGFloat,
        constraint: PhotoFramingConstraint,
        allowsNone: Bool
    ) -> CGSize {
        if constraint == .none, allowsNone { return proposed }

        switch constraint {
        case .none:
            return .zero
        case .cover:
            // Express screen translation in the image's local rotated axes.
            let c = cos(radians)
            let s = sin(radians)
            let localX = c * proposed.width + s * proposed.height
            let localY = -s * proposed.width + c * proposed.height

            let halfFrameW = frameSize.width / 2
            let halfFrameH = frameSize.height / 2
            let cropExtentX = abs(c) * halfFrameW + abs(s) * halfFrameH
            let cropExtentY = abs(s) * halfFrameW + abs(c) * halfFrameH
            let maxLocalX = max(0, imageSize.width / 2 - cropExtentX)
            let maxLocalY = max(0, imageSize.height / 2 - cropExtentY)
            let clampedX = min(max(localX, -maxLocalX), maxLocalX)
            let clampedY = min(max(localY, -maxLocalY), maxLocalY)

            return CGSize(
                width: c * clampedX - s * clampedY,
                height: s * clampedX + c * clampedY
            )

        case .overlap:
            // Keep at least one image edge at or beyond the visual frame. Also
            // keep the image from being dragged completely out of view.
            let rotatedBounds = rotatedBoundingSize(imageSize, radians: radians)
            let maxX = max(frameSize.width, rotatedBounds.width) / 2
            let maxY = max(frameSize.height, rotatedBounds.height) / 2
            var result = CGSize(
                width: min(max(proposed.width, -maxX), maxX),
                height: min(max(proposed.height, -maxY), maxY)
            )

            let containedX = abs(result.width) + rotatedBounds.width / 2 < frameSize.width / 2
            let containedY = abs(result.height) + rotatedBounds.height / 2 < frameSize.height / 2
            if containedX && containedY {
                let pushX = max(0, frameSize.width / 2 - rotatedBounds.width / 2)
                let pushY = max(0, frameSize.height / 2 - rotatedBounds.height / 2)
                if pushX <= pushY {
                    result.width = result.width < 0 ? -pushX : pushX
                } else {
                    result.height = result.height < 0 ? -pushY : pushY
                }
            }
            return result
        }
    }

    private static func rotatedBoundingSize(_ size: CGSize, radians: CGFloat) -> CGSize {
        let c = abs(cos(radians))
        let s = abs(sin(radians))
        return CGSize(
            width: c * size.width + s * size.height,
            height: s * size.width + c * size.height
        )
    }
}
#endif
