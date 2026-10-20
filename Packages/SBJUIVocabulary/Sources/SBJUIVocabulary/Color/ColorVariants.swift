import Foundation
import SBJDataDefinition
import SwiftUI
import UIKit

/// Common sources from which a `CodableColor` can be constructed.
/// Platform-specific cases exist only where their native color type exists.
///
/// Application-facing concrete color sources accepted by `CodableColor`.
///
/// This is not itself localization policy. Concrete colors may later participate
/// as candidates in localization/presentation-resource resolution.
public enum ColorVariants {
    case parts(Double, Double, Double, Double = 1.0)
    case swiftUI(Color)
    case asset(String)
#if canImport(UIKit)
    case uiKit(UIColor)
#endif
}

public extension CodableColor {
    init(color: ColorVariants) {
        switch color {
        case let .parts(red, green, blue, opacity):
            self.init(red, green, blue, opacity)
        case let .swiftUI(color):
            self.init(color: color.resolve(in: .init()))
        case let .asset(name):
            self.init(color: Color(name).resolve(in: .init()))
#if canImport(UIKit)
        case let .uiKit(color):
            self.init(color: color)
#endif
        }
    }

    init(color: Color) {
        self.init(color: color.resolve(in: .init()))
    }
}
