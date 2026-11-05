import CoreGraphics
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit) || canImport(AppKit)
/// Native-image adapters shared by AppKit and UIKit callers.
/// The CGImage accessor returns backing pixels; it does not normalize EXIF/UIImage orientation.
public extension SBJImage {
    var sbjCGImage: CGImage? {
        #if canImport(UIKit)
        return cgImage
        #else
        return cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }

    var sbjSwiftUIImage: Image {
        #if canImport(UIKit)
        return Image(uiImage: self)
        #else
        return Image(nsImage: self)
        #endif
    }
}
#endif
