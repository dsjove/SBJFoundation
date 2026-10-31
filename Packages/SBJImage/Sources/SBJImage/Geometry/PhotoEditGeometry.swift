import CoreGraphics
import Foundation
import SBJLocalization
import SBJDataDefinition

@SBJStructure
public struct PhotoEditGeometry: Codable, Equatable, Sendable {
    public var crop: PhotoCropState
    public var placement: NormalizedPhotoOffset = .zero
    @SBJNumber(min: 1)
    public var magnification: Double = 1
    public var rotation = PhotoRotation()
    public var mirror = PhotoMirrorState()
    public var perspective = PhotoPerspective.identity
    public var skew = PhotoSkew.identity

    public init(crop: PhotoCropState, placement: NormalizedPhotoOffset = .zero, magnification: Double = 1, rotation: PhotoRotation = .init(), mirror: PhotoMirrorState = .init(), perspective: PhotoPerspective = .identity, skew: PhotoSkew = .identity) {
        self.crop = crop; self.placement = placement; self.magnification = magnification; self.rotation = rotation; self.mirror = mirror; self.perspective = perspective; self.skew = skew
    }

    private enum CodingKeys: String, CodingKey { case crop, placement, magnification, rotation, mirror, perspective, skew }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        crop = try c.decode(PhotoCropState.self, forKey: .crop)
        placement = try c.decodeIfPresent(NormalizedPhotoOffset.self, forKey: .placement) ?? .zero
        magnification = try c.decodeIfPresent(Double.self, forKey: .magnification) ?? 1
        rotation = try c.decodeIfPresent(PhotoRotation.self, forKey: .rotation) ?? .init()
        mirror = try c.decodeIfPresent(PhotoMirrorState.self, forKey: .mirror) ?? .init()
        perspective = try c.decodeIfPresent(PhotoPerspective.self, forKey: .perspective) ?? .identity
        skew = try c.decodeIfPresent(PhotoSkew.self, forKey: .skew) ?? .identity
    }

    public mutating func resetPreservingCrop() {
        resetPlacementAndMagnification()
        rotation = .init()
        mirror = .init()
        perspective = .identity
        skew = .identity
    }

    public mutating func prepareForEditing(
        supportedCropOptions: [PhotoCropOption],
        sourceSize: CGSize
    ) {
        crop.prepareForEditing(
            supportedOptions: supportedCropOptions,
            sourceSize: sourceSize
        )
    }

    public mutating func selectCrop(_ option: PhotoCropOption) {
        crop.select(option)
        resetPlacementAndMagnification()
    }

    public mutating func setCropDimensionsSwapped(_ isSwapped: Bool) {
        crop.setDimensionsSwapped(isSwapped)
        resetPlacementAndMagnification()
    }

    public mutating func resizeFreeCrop(to aspectRatio: Double) {
        crop.resizeFreeCrop(to: aspectRatio)
        resetPlacementAndMagnification()
    }

    public mutating func setPlacement(_ placement: NormalizedPhotoOffset) {
        self.placement = placement
    }

    public mutating func setMagnification(_ magnification: Double, maximum: Double) {
        self.magnification = min(max(magnification, 1), maximum)
    }

#if !os(watchOS) && !os(tvOS) && canImport(UIKit)
    public func constrained(
        sourceSize: CGSize,
        containerSize: CGSize,
        options: PhotoEditorOptions
    ) -> Self {
        var result = self
        let layout = PhotoGeometryResolver.resolve(
            sourceSize: sourceSize,
            containerSize: containerSize,
            geometry: self,
            options: options
        )
        result.setPlacement(
            PhotoGeometryResolver.normalizedPlacement(
                for: layout.translation,
                renderedImageSize: layout.renderedImageSize
            )
        )
        result.setMagnification(result.magnification, maximum: options.maximumMagnification)
        return result
    }

    public func panned(
        by translation: CGSize,
        sourceSize: CGSize,
        containerSize: CGSize,
        options: PhotoEditorOptions
    ) -> Self {
        let startLayout = PhotoGeometryResolver.resolve(
            sourceSize: sourceSize,
            containerSize: containerSize,
            geometry: self,
            options: options
        )
        let proposedTranslation = CGSize(
            width: startLayout.translation.width + translation.width,
            height: startLayout.translation.height + translation.height
        )
        var proposed = self
        proposed.setPlacement(
            PhotoGeometryResolver.normalizedPlacement(
                for: proposedTranslation,
                renderedImageSize: startLayout.renderedImageSize
            )
        )
        return proposed.constrained(
            sourceSize: sourceSize,
            containerSize: containerSize,
            options: options
        )
    }

    public func magnified(
        by scale: Double,
        sourceSize: CGSize,
        containerSize: CGSize,
        options: PhotoEditorOptions
    ) -> Self {
        var proposed = self
        proposed.setMagnification(magnification * scale, maximum: options.maximumMagnification)
        return proposed.constrained(
            sourceSize: sourceSize,
            containerSize: containerSize,
            options: options
        )
    }

#endif

    public mutating func resetPlacementAndMagnification() {
        placement = .zero
        magnification = 1
    }

    public mutating func rotate(clockwise: Bool) {
        rotation.rotate(clockwise: clockwise)
    }

    public mutating func setFineRotation(_ degrees: Double) {
        rotation.fineDegrees = min(max(degrees, -15), 15)
    }

    public mutating func resetRotation() {
        rotation = .init()
    }

    public mutating func resetStraighten() {
        rotation.fineDegrees = 0
    }

    public mutating func toggleMirror(_ axis: PhotoMirrorAxis) {
        mirror.toggle(axis)
    }

    public var hasPlacementOrMagnificationEdits: Bool {
        placement != .zero || magnification != 1
    }

    public var hasStraightenEdit: Bool {
        rotation.fineDegrees != 0
    }

    public var editComparisonValue: Self {
        var result = self
        switch result.crop.option {
        case .original, .ratio:
            return result
        case .none, .square, .free:
            result.crop.swapsDimensions = false
            return result
        }
    }


}
