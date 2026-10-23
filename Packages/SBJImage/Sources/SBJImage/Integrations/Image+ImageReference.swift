import Foundation
import SwiftUI
import SBJFileResources
import SBJUIVocabulary
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(UIKit)
import UIKit
#endif

public extension Image {
    init(_ reference: ImageReference) {
        switch reference {
        case .none: self = Image("")
        case .symbol(let symbol): self = symbol.image
        case .file(let url):
            #if canImport(ImageIO)
            self = url.withSecurityScopedAccess { scopedURL in
                if let source = CGImageSourceCreateWithURL(scopedURL as CFURL, nil),
                   let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                    return Image(decorative: cgImage, scale: 1)
                }
                #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
                if let thumbnail = SBJImageDocument.thumbnailImage(at: scopedURL, renderIfNeeded: false) {
                    return Image(uiImage: thumbnail)
                }
                #endif
                return Image("")
            }
            #else
            self = Image("")
            #endif
        }
    }
}
