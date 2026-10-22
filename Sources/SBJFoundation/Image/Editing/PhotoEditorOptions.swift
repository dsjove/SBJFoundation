import SBJDataDefinition
import CoreGraphics
import Foundation
import SBJLocalization

@SBJStructure
public struct PhotoEditorOptions: Codable, Equatable, Sendable, Hashable {
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


}
