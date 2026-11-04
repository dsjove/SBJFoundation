import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#if !os(watchOS) && (canImport(UIKit) || canImport(AppKit))
public extension SBJImage {
    func resized(toFit size: CGSize) -> SBJImage {
		guard size.width > 0, size.height > 0,
			  self.size.width > 0, self.size.height > 0
		else {
			return self
		}

		let scale = min(
			1,
			size.width / self.size.width,
			size.height / self.size.height
		)

		guard scale < 1 else {
			return self
		}

		let targetSize = CGSize(
			width: self.size.width * scale,
			height: self.size.height * scale
		)

        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        #else
        return NSImage(size: targetSize, flipped: false) { rect in
            self.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        #endif
    }
}
#endif
