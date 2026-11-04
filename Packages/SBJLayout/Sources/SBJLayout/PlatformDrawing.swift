import CoreGraphics
#if os(macOS)
import AppKit

// AppKit does not expose UIFont.lineHeight; retain a single text layout path.
extension NSFont {
    var lineHeight: CGFloat { ceil(ascender - descender + leading) }
}
#endif
