#if canImport(UIKit)
import UIKit
public typealias SBJColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias SBJColor = NSColor
#endif

public extension SBJColor {
    var brightness: CGFloat {
        #if canImport(UIKit)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return 0 }
        #else
        guard let rgb = usingColorSpace(.deviceRGB) else { return 0 }
        let red = rgb.redComponent, green = rgb.greenComponent, blue = rgb.blueComponent
        #endif
        return (red * 299 + green * 587 + blue * 114) / 1000
    }

    var isLight: Bool { brightness > 0.5 }
}
