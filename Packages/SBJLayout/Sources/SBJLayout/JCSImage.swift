import CoreGraphics
import SBJLocalization
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct JCSImage: Renderable {
	public let cornerRadius: CGFloat
	public let aspect: Aspect
	public let image: SBJImage?

	public init(
		_ image: SBJImage?,
		aspect: Aspect = .fit,
		cornerRadius: CGFloat = 0.0
	) {
		self.cornerRadius = cornerRadius
		self.aspect = aspect
		self.image = image
	}

	public var isEmpty: Bool {
		image == nil
	}

	public func measure(bounds: CGSize) -> CGSize {
		aspect.apply(size: image?.size ?? .zero, in: bounds)
	}

	public func minimumMeasure(bounds: CGSize) -> CGSize {
		// Images currently have no separate semantic minimum. Preserve the existing
		// aspect-sizing contract until image-specific minimum policy is required.
		measure(bounds: bounds)
	}

	public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
		if let image = image {
			let sized = aspect.apply(size: image.size, in: allocated.size)
			let placed = align.apply(size: sized, in: allocated)
			#if canImport(AppKit) && !canImport(UIKit)
            let ctx = NSGraphicsContext.current?.cgContext
#else
            let ctx = UIGraphicsGetCurrentContext()
#endif
            if let ctx {
				ctx.saveGState()
				defer { ctx.restoreGState() }
				if cornerRadius > 0 {
					let path = CGPath(roundedRect: placed, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
					ctx.addPath(path)
					ctx.clip()
				}
				image.draw(in: placed)
			}
		}
	}
}
