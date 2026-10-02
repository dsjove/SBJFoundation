import CoreGraphics
import Foundation

@SBJStructure
public struct NormalizedPhotoOffset: SBJFoundationType, Sendable {
    @SBJNumber(range: -1...1)
    public var x: Double = 0
    @SBJNumber(range: -1...1)
    public var y: Double = 0

    public init(x: Double = 0, y: Double = 0) { self.x = x; self.y = y }
    public static let zero = Self()

    public static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
        switch keyPath as AnyKeyPath {
        case \Self.x: return SBJPropertyInfo(title: "Horizontal Placement", summary: "Horizontal image placement normalized to the rendered image width.", details: "A value of 0 is centered; positive values move right and negative values move left.", accessibilityLabel: "Horizontal Image Placement", accessibilityHint: "Drag the image left or right within the crop.")
        case \Self.y: return SBJPropertyInfo(title: "Vertical Placement", summary: "Vertical image placement normalized to the rendered image height.", details: "A value of 0 is centered; positive values move down and negative values move up.", accessibilityLabel: "Vertical Image Placement", accessibilityHint: "Drag the image up or down within the crop.")
        default: return nil
        }
    }
}

@SBJStructure
public struct PhotoRotation: SBJFoundationType, Sendable {
    @SBJInteger(range: 0...3)
    public var quarterTurns: Int = 0
    @SBJNumber(range: -15...15)
    public var fineDegrees: Double = 0

    public init(quarterTurns: Int = 0, fineDegrees: Double = 0) { self.quarterTurns = quarterTurns; self.fineDegrees = fineDegrees }
    public var degrees: Double { Double(((quarterTurns % 4) + 4) % 4) * 90 + fineDegrees }
    public mutating func rotate(clockwise: Bool) { quarterTurns += clockwise ? 1 : -1; quarterTurns = ((quarterTurns % 4) + 4) % 4 }

    public static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
        switch keyPath as AnyKeyPath {
        case \Self.quarterTurns: return SBJPropertyInfo(title: "Quarter Turns", summary: "Number of 90-degree clockwise rotations, normalized to zero through three.", details: "Quarter-turn controls may rotate in either direction; the stored representation remains normalized modulo four.", accessibilityLabel: "Quarter Turn Rotation", accessibilityHint: "Rotates the image by 90 degrees.")
        case \Self.fineDegrees: return SBJPropertyInfo(title: "Straighten", summary: "Fine rotation used by the straighten control.", details: "The editor constrains interactive straightening to -15 through 15 degrees.", accessibilityLabel: "Straighten", accessibilityHint: "Adjust the image rotation in small increments.")
        default: return nil
        }
    }
}

@SBJStructure
public struct PhotoMirrorState: SBJFoundationType, Sendable {
    public var horizontal = false
    public var vertical = false
    public init(horizontal: Bool = false, vertical: Bool = false) { self.horizontal = horizontal; self.vertical = vertical }
    public mutating func toggle(_ axis: PhotoMirrorAxis) { switch axis { case .horizontal: horizontal.toggle(); case .vertical: vertical.toggle() } }
    public static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
        switch keyPath as AnyKeyPath {
        case \Self.horizontal: return SBJPropertyInfo(summary: "Whether the image is mirrored left-to-right.", details: "False preserves the source orientation; true reflects the image across its vertical axis.", accessibilityLabel: "Mirror Horizontally", accessibilityHint: "Reflects the image from left to right.")
        case \Self.vertical: return SBJPropertyInfo(summary: "Whether the image is mirrored top-to-bottom.", details: "False preserves the source orientation; true reflects the image across its horizontal axis.", accessibilityLabel: "Mirror Vertically", accessibilityHint: "Reflects the image from top to bottom.")
        default: return nil
        }
    }
}

@SBJStructure
public struct PhotoCropState: SBJFoundationType, Sendable {
    public var option: PhotoCropOption
    @SBJNumber(range: 0.25...4)
    public var freeAspectRatio: Double
    public var swapsDimensions: Bool

    public init(option: PhotoCropOption, sourceSize: CGSize, swapsDimensions: Bool = false) {
        self.option = option; self.freeAspectRatio = sourceSize.height > 0 ? Double(sourceSize.width / sourceSize.height) : 1; self.swapsDimensions = swapsDimensions
    }
    public init(option: PhotoCropOption, freeAspectRatio: Double, swapsDimensions: Bool = false) {
        self.option = option; self.freeAspectRatio = freeAspectRatio; self.swapsDimensions = swapsDimensions
    }

    private enum CodingKeys: String, CodingKey { case option, freeAspectRatio, swapsDimensions }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        option = try c.decodeIfPresent(PhotoCropOption.self, forKey: .option) ?? .none
        freeAspectRatio = try c.decode(Double.self, forKey: .freeAspectRatio)
        swapsDimensions = try c.decodeIfPresent(Bool.self, forKey: .swapsDimensions) ?? false
    }

    public mutating func select(_ option: PhotoCropOption) {
        self.option = option
    }

    public mutating func setDimensionsSwapped(_ isSwapped: Bool) {
        swapsDimensions = isSwapped
    }

    public mutating func resizeFreeCrop(to aspectRatio: Double) {
        freeAspectRatio = min(max(aspectRatio, 0.25), 4)
    }

    public mutating func prepareForEditing(
        supportedOptions: [PhotoCropOption],
        sourceSize: CGSize
    ) {
        guard !supportedOptions.isEmpty,
              !supportedOptions.contains(option),
              let fallback = supportedOptions.first else {
            return
        }

        let previousOption = option
        option = fallback
        swapsDimensions = false
        if fallback == .free, previousOption != .free {
            freeAspectRatio = sourceSize.height > 0
                ? Double(sourceSize.width / sourceSize.height)
                : 1
        }
    }

    public static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
        switch keyPath as AnyKeyPath {
        case \Self.option: return SBJPropertyInfo(title: "Crop", summary: "Active crop mode.", details: "None represents uncropped editing; ratio crops may transpose width and height using swapsDimensions.", accessibilityLabel: "Crop", accessibilityHint: "Choose the shape and aspect ratio of the visible image.")
        case \Self.freeAspectRatio: return SBJPropertyInfo(title: "Free Crop Aspect Ratio", summary: "Current width-to-height ratio of the resizable free crop.", details: "The editor constrains interactive free crop ratios to 0.25 through 4.", accessibilityLabel: "Resize Free Crop", accessibilityHint: "Drag to change the width and height of the free crop.")
        case \Self.swapsDimensions: return SBJPropertyInfo(title: "Swap Width and Height", summary: "Transposes width and height for Original and dimensional ratio crops.", details: "This has no geometric effect for None, Square, or Free crop modes.", accessibilityLabel: "Swap Width and Height", accessibilityHint: "Transposes the width and height of the current crop when supported.")
        default: return nil
        }
    }
}

/// Reserved perspective state for the portable non-destructive format.
/// Identity is the unit square. Rendering/editing of non-identity values is intentionally not implemented yet.
public struct PhotoPerspective: SBJFoundationType, Sendable {
    public struct Point: SBJFoundationType, Sendable { public var x: Double; public var y: Double; public init(x: Double, y: Double) { self.x = x; self.y = y } }
    public var topLeft: Point; public var topRight: Point; public var bottomLeft: Point; public var bottomRight: Point
    public init(topLeft: Point = .init(x: 0, y: 0), topRight: Point = .init(x: 1, y: 0), bottomLeft: Point = .init(x: 0, y: 1), bottomRight: Point = .init(x: 1, y: 1)) { self.topLeft = topLeft; self.topRight = topRight; self.bottomLeft = bottomLeft; self.bottomRight = bottomRight }
    public static let identity = Self()
    public var isIdentity: Bool { self == .identity }
}

/// Reserved skew state for the portable non-destructive format. Values are degrees.
/// Rendering/editing of non-zero values is intentionally not implemented yet.
public struct PhotoSkew: SBJFoundationType, Sendable {
    public var horizontalDegrees: Double
    public var verticalDegrees: Double
    public init(horizontalDegrees: Double = 0, verticalDegrees: Double = 0) { self.horizontalDegrees = horizontalDegrees; self.verticalDegrees = verticalDegrees }
    public static let identity = Self()
    public var isIdentity: Bool { self == .identity }
}

/// Geometry is the complete geometric adjustment recipe. It is state, not edit history.
@SBJStructure
public struct PhotoEditGeometry: SBJFoundationType, Sendable {
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

    public static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
        switch keyPath as AnyKeyPath {
        case \Self.crop: return SBJPropertyInfo(summary: "Crop selection and crop-specific geometry.", details: "Contains the selected crop mode, free-crop aspect ratio, and width/height transpose state.")
        case \Self.placement: return SBJPropertyInfo(summary: "Normalized pan position of the image within the edit frame.", details: "Placement is stored relative to rendered image dimensions so it remains independent of screen point size.", accessibilityLabel: "Image Position", accessibilityHint: "Drag to reposition the image inside the crop.")
        case \Self.magnification: return SBJPropertyInfo(summary: "User zoom relative to the minimum scale required by the current framing policy.", details: "A value of 1 is the minimum legal scale before user zoom is applied.", accessibilityLabel: "Image Magnification", accessibilityHint: "Pinch to zoom the image inside the crop.")
        case \Self.rotation: return SBJPropertyInfo(summary: "Quarter-turn and straighten rotation state.", details: "Quarter turns and fine straightening are combined when resolving the final image transform.")
        case \Self.mirror: return SBJPropertyInfo(summary: "Horizontal and vertical mirror state.", details: "Mirror axes are stored independently even when the editor UI exposes only the non-redundant axis.")
        case \Self.perspective: return SBJPropertyInfo(summary: "Reserved perspective correction state.", details: "Serialized for document interchange; non-identity perspective rendering is not implemented yet.")
        case \Self.skew: return SBJPropertyInfo(summary: "Reserved horizontal and vertical skew state.", details: "Serialized for document interchange; non-identity skew rendering is not implemented yet.")
        default: return nil
        }
    }
}


/// Reserved color recipe. Kept as a distinct Codable object so future color controls do not change the document container schema.
public struct PhotoColorAdjustments: SBJFoundationType, Sendable {
    public init() {}
}
