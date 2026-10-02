import CoreGraphics
import Foundation

@SBJStructure
public enum PhotoCropOption: SBJFoundationType, Hashable, Sendable, Identifiable {
    case none
    case original
    case square
    case ratio(width: Int, height: Int)
    case free

    public var id: String {
        switch self {
        case .none: return "none"
        case .original: return "original"
        case .square: return "square"
        case .ratio(let width, let height): return "ratio-\(width)-\(height)"
        case .free: return "free"
        }
    }

    public var title: String {
        title(swappingDimensions: false)
    }

    func title(swappingDimensions: Bool) -> String {
        switch self {
        case .none: return "None"
        case .original: return "Original"
        case .square: return "Square"
        case .ratio(let width, let height):
            return swappingDimensions ? "\(height):\(width)" : "\(width):\(height)"
        case .free: return "Free"
        }
    }

    var supportsDimensionSwap: Bool {
        switch self {
        case .original, .ratio:
            return true
        case .none, .square, .free:
            return false
        }
    }

    public static let fourThree: Self = .ratio(width: 4, height: 3)
    public static let threeTwo: Self = .ratio(width: 3, height: 2)
    public static let sixteenNine: Self = .ratio(width: 16, height: 9)
    public static let fourFive: Self = .ratio(width: 4, height: 5)
    public static let fiveSeven: Self = .ratio(width: 5, height: 7)

    func aspectRatio(
        sourceSize: CGSize,
        freeAspectRatio: Double,
        swappingDimensions: Bool = false
    ) -> CGFloat {
        switch self {
        case .none:
            guard sourceSize.height > 0 else { return 1 }
            return sourceSize.width / sourceSize.height
        case .original:
            guard sourceSize.width > 0, sourceSize.height > 0 else { return 1 }
            return swappingDimensions
                ? sourceSize.height / sourceSize.width
                : sourceSize.width / sourceSize.height
        case .square:
            return 1
        case .ratio(let width, let height):
            guard width > 0, height > 0 else { return 1 }
            return swappingDimensions
                ? CGFloat(height) / CGFloat(width)
                : CGFloat(width) / CGFloat(height)
        case .free:
            return max(0.1, CGFloat(freeAspectRatio))
        }
    }
}

@SBJStructure
public enum PhotoFramingConstraint: SBJFoundationType, Sendable, Hashable {
    /// The transformed image must cover the complete crop/output rectangle.
    case cover
    /// The transformed image may expose frame background, but may not become
    /// completely contained inside the visual frame.
    case overlap
    /// No framing constraint is imposed by the editor.
    case none
}

@SBJStructure
public enum PhotoMirrorAxis: String, SBJFoundationType, Sendable, Hashable {
    case horizontal
    case vertical
}

/// Capabilities and policy for one PhotoEditor presentation.
///
/// This value deliberately describes what the caller permits. It contains no
/// user edit state; that lives in PhotoEditGeometry.
@SBJStructure
public struct PhotoEditorOptions: SBJFoundationType, Sendable, Hashable {
    @SBJArray(unique: true)
    public var cropOptions: [PhotoCropOption]
    public var initialCrop: PhotoCropOption
    public var allowsQuarterTurnRotation: Bool
    public var allowsFreeRotation: Bool
    public var allowsMirror: Bool
    public var framingConstraint: PhotoFramingConstraint
    public var allowsNoneFraming: Bool
    @SBJNumber(min: 1)
    public var maximumMagnification: Double
    /// Opacity of the image drawn outside the active crop. Values <= 0 disable
    /// the crop ghost. Values above 1 are rendered as fully opaque.
    public var renderCropGhost: Double
    public var allowsMarkup: Bool
    public var allowsShare: Bool

    public init(
        cropOptions: [PhotoCropOption] = [.none, .original, .square, .fourThree, .threeTwo, .sixteenNine, .free],
        initialCrop: PhotoCropOption = .none,
        allowsQuarterTurnRotation: Bool = true,
        allowsFreeRotation: Bool = true,
        allowsMirror: Bool = true,
        framingConstraint: PhotoFramingConstraint = .overlap,
        allowsNoneFraming: Bool = true,
        maximumMagnification: Double = 8,
        renderCropGhost: Double = 0.35,
        allowsMarkup: Bool = true,
        allowsShare: Bool = true
    ) {
        self.cropOptions = cropOptions
        self.initialCrop = initialCrop
        self.allowsQuarterTurnRotation = allowsQuarterTurnRotation
        self.allowsFreeRotation = allowsFreeRotation
        self.allowsMirror = allowsMirror
        self.framingConstraint = framingConstraint
        self.allowsNoneFraming = allowsNoneFraming
        self.maximumMagnification = max(1, maximumMagnification)
        self.renderCropGhost = renderCropGhost
        self.allowsMarkup = allowsMarkup
        self.allowsShare = allowsShare
    }

    /// Character/avatar-style editing: a required square crop with the common
    /// geometry tools and markup.
    public static let portrait = PhotoEditorOptions(
        cropOptions: [.square],
        framingConstraint: .cover
    )

    public static let `default` = PhotoEditorOptions()

    /// Crop mode used when beginning a new edit.
    ///
    /// With no crop options, cropping is disabled. With exactly one option,
    /// that option is enforced. With multiple options, `initialCrop` is used
    /// when available; otherwise the first configured option is used.
    var effectiveInitialCrop: PhotoCropOption {
        switch cropOptions.count {
        case 0:
            return .none
        case 1:
            return cropOptions[0]
        default:
            return cropOptions.contains(initialCrop) ? initialCrop : cropOptions[0]
        }
    }

    /// Whether the crop control needs to offer a choice of crop modes.
    var showsCropChoices: Bool {
        cropOptions.count > 1
    }

    /// Whether any configured crop mode has distinct width/height orientation.
    /// Square, none, and free crops do not benefit from dimension swapping.
    var allowsCropDimensionSwap: Bool {
        cropOptions.contains { $0.supportsDimensionSwap }
    }

    /// Quarter-turn rotation makes a vertical mirror redundant from the user's
    /// point of view (180° + horizontal mirror). When quarter-turn rotation is
    /// unavailable, expose both mirror axes.
    public var availableMirrorAxes: Set<PhotoMirrorAxis> {
        guard allowsMirror else { return [] }
        return allowsQuarterTurnRotation ? [.horizontal] : [.horizontal, .vertical]
    }

    public static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
        switch keyPath as AnyKeyPath {
        case \Self.cropOptions:
            return SBJPropertyInfo(
                title: "Crop Options",
                summary: "Crop modes offered by the photo editor.",
                details: "Include None when uncropped editing is allowed. The order is the order presented in the crop menu."
            )
        case \Self.initialCrop:
            return SBJPropertyInfo(
                title: "Initial Crop",
                summary: "Preferred starting crop when more than one crop mode is available.",
                details: "Ignored when cropOptions is empty or contains one option. With multiple options, if this crop is not present, the first configured crop option is used."
            )
        case \Self.allowsQuarterTurnRotation:
            return SBJPropertyInfo(
                title: "Quarter-Turn Rotation",
                summary: "Whether 90-degree rotation controls are available.",
                details: "When enabled, the editor exposes quarter-turn rotation and can omit a redundant vertical mirror control."
            )
        case \Self.allowsFreeRotation:
            return SBJPropertyInfo(
                title: "Straightening",
                summary: "Whether fine rotation is available for straightening an image.",
                details: "Fine rotation uses the straighten control and is constrained by the PhotoRotation model."
            )
        case \Self.allowsMirror:
            return SBJPropertyInfo(
                title: "Mirroring",
                summary: "Whether image mirror controls are available.",
                details: "The available axes also depend on whether quarter-turn rotation is enabled."
            )
        case \Self.framingConstraint:
            return SBJPropertyInfo(
                title: "Framing Constraint",
                summary: "Controls how an uncropped image may move relative to the editor frame.",
                details: "Active crops always use cover framing so the crop rectangle cannot expose empty pixels."
            )
        case \Self.maximumMagnification:
            return SBJPropertyInfo(
                title: "Maximum Magnification",
                summary: "Largest user zoom relative to the minimum legal image scale.",
                details: "Values below 1 are normalized to 1 by the initializer."
            )
        case \Self.renderCropGhost:
            return SBJPropertyInfo(
                title: "Crop Ghost Opacity",
                summary: "Opacity of the uncropped image shown behind the active crop.",
                details: "Values less than or equal to zero disable the ghost. Values above 1 render as fully opaque."
            )
        case \Self.allowsNoneFraming:
            return SBJPropertyInfo(
                title: "Allows Unconstrained Framing",
                summary: "Permits the .none framing policy to leave image placement unconstrained.",
                details: "This affects uncropped editing; crop modes still require the image to cover the crop frame."
            )
        case \Self.allowsMarkup:
            return SBJPropertyInfo(
                title: "Markup",
                summary: "Whether drawing and markup tools are available.",
                details: "Markup is rendered into the completed image when present."
            )
        case \Self.allowsShare:
            return SBJPropertyInfo(
                title: "Sharing",
                summary: "Whether the editor exposes sharing for the current edited image.",
                details: "Sharing renders the current edit state without completing the editor."
            )
        default:
            return nil
        }
    }
}
