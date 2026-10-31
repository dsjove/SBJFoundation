import CoreGraphics
import Foundation
import SBJLocalization
import SBJDataDefinition

@SBJStructure
public enum PhotoCropOption: Codable, Hashable, Sendable, Identifiable {
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
