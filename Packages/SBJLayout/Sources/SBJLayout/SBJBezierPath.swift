import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import SBJUIVocabulary

public extension SBJBezierPath {
	convenience init(borderRect rect: CGRect, cornerRadius: CGFloat?) {
		if let cornerRadius, cornerRadius > 0.0 {
			self.init(roundedRect: rect, cornerRadius: cornerRadius)
		} else {
			self.init(rect: rect)
		}
	}
}

#if canImport(AppKit) && !canImport(UIKit)
public typealias SBJBezierPath = NSBezierPath
public extension NSBezierPath {
    convenience init(roundedRect rect: CGRect, cornerRadius: CGFloat) {
        self.init(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    }
    func addLine(to point: CGPoint) { line(to: point) }
}
#else
public typealias SBJBezierPath = UIBezierPath
#endif
