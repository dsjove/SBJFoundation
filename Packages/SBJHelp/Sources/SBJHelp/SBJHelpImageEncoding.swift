#if canImport(UIKit) || canImport(AppKit)
import Foundation
import SBJLocalization
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Single PNG conversion boundary for help images and app icons.
enum SBJHelpImageEncoding {
    static func pngData(for image: SBJImage?) -> Data? {
        guard let image else { return nil }
#if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let rendered = renderer.image { context in
            (UIColor(named: "AccentColor") ?? .systemBlue).setFill()
            guard let cgImage = image.cgImage else {
                image.draw(in: CGRect(origin: .zero, size: image.size))
                return
            }
            context.cgContext.translateBy(x: 0, y: image.size.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            let rect = CGRect(origin: .zero, size: image.size)
            context.cgContext.clip(to: rect, mask: cgImage)
            context.cgContext.fill(rect)
        }
        return rendered.pngData()
#elseif canImport(AppKit)
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        // Rasterize symbol/vector representations before encoding to PNG.
        let width = max(1, Int(ceil(image.size.width)))
        let height = max(1, Int(ceil(image.size.height)))
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height),
                   from: .zero, operation: .sourceOver, fraction: 1)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])
#endif
    }
}
#endif
