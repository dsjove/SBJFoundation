import SBJDataDefinition
import CoreGraphics
import Foundation
import SBJLocalization


@SBJStructure
public struct PhotoCropState: Codable, Equatable, Sendable {
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


}
