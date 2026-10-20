import SBJUIVocabulary
import SBJFileResources
import SBJDataDefinition
import Foundation
import SwiftUI
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(UIKit)
import UIKit
import SBJLocalization
#endif

/// General image reference: obtain an image from symbolic, bundled or file-backed sources.
/// `SBJSymbol` is restricted to local UI symbology; `.file` also resolves image-document thumbnails.
public enum ImageReference: Sendable, Hashable {
    case none
    case symbol(SBJSymbol)
    case file(URL)

    /// Source-compatible constructor for an SF Symbol.
    public static func system(_ name: String) -> Self { .symbol(.system(name)) }
    /// Source-compatible constructor for an image asset in an asset catalog.
    public static func asset(_ name: String, bundle: Bundle? = nil) -> Self {
        .symbol(.asset(name, bundle: bundle))
    }
    /// Source-compatible constructor for a bundled image file.
    public static func resource(name: String, extension ext: String? = nil, subdirectory: String? = nil, bundle: Bundle? = nil) -> Self {
        .symbol(.bundleImage(name: name, extension: ext, subdirectory: subdirectory, bundle: bundle))
    }
    public static func resource(_ fileName: String, bundle: Bundle? = nil) -> Self {
        let path = fileName as NSString
        let lastComponent = path.lastPathComponent as NSString
        let ext = lastComponent.pathExtension
        let name = ext.isEmpty ? String(lastComponent) : lastComponent.deletingPathExtension
        let directory = path.deletingLastPathComponent
        return .resource(name: name, extension: ext.isEmpty ? nil : ext,
                         subdirectory: directory.isEmpty || directory == "." ? nil : directory,
                         bundle: bundle)
    }
    @available(*, deprecated, renamed: "asset(_:bundle:)")
    public static func bundled(_ name: String, bundle: Bundle? = nil) -> Self { .asset(name, bundle: bundle) }

    public var isEmpty: Bool {
        switch self {
        case .none: return true
        case .symbol(let symbol): return symbol.isEmpty
        case .file(let url): return url.path.isEmpty
        }
    }
}

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

// ImageReference is Foundation-owned; keep this overload outside SBJUIVocabulary.
public extension SBJSelectionMenu {
    init(
        _ title: LocalizedStringKey,
        image: ImageReference,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(content: content) {
            Label(title, image: image)
        }
    }
}

public extension Label where Title == Text, Icon == Image {
    init(_ title: LocalizedStringKey, image: ImageReference) {
        self = Label { Text(title) } icon: { Image(image) }
    }
    init(_ title: String, image: ImageReference) {
        self = Label { Text(title) } icon: { Image(image) }
    }
}

#if canImport(UIKit)
public extension ImageReference {
    var image: UIImage? {
        switch self {
        case .none: return nil
        case .symbol(let symbol): return symbol.uiImage
        case .file(let url):
            return url.withSecurityScopedAccess { scopedURL in
                if let image = UIImage(contentsOfFile: scopedURL.path) { return image }
                #if !os(watchOS) && !os(tvOS)
                return SBJImageDocument.thumbnailImage(at: scopedURL, renderIfNeeded: false)
                #else
                return nil
                #endif
            }
        }
    }
    var data: Data? { image?.pngData() }
}
#endif
