import Foundation
import SwiftUI
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(UIKit)
import UIKit
#endif
import SBJFileResources
import SBJDataDefinition
import SBJUIVocabulary

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
