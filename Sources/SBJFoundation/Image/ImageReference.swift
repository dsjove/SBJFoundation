import Foundation

/// A concrete reference to image content used by reusable UI vocabulary.
///
/// `ImageReference` describes images, not arbitrary bundle data. It intentionally supports
/// the image sources that presentation code needs directly:
///
/// - image sets in an asset catalog (`asset`)
/// - ordinary image files copied/processed into a bundle (`resource`)
/// - SF Symbols (`system`)
/// - file URLs (`file`)
/// - SBJ non-destructive image document package URLs (`document`)
/// - no image (`none`)
///
/// `SBJAssetReference` remains the generic data-loading reference for asset-catalog *data sets*
/// and arbitrary bundle resources such as HTML and CSS. The two types share bundle-resource
/// lookup behavior, but not responsibility.
public enum ImageReference: Sendable, Hashable {
    case none
    case asset(String, bundle: Bundle? = nil)
    case resource(
        name: String,
        extension: String? = nil,
        subdirectory: String? = nil,
        bundle: Bundle? = nil
    )
    case system(String)
    // TODO: support async non-file URLs
    case file(URL)
    case document(URL)

    /// Convenience for an ordinary bundled image file such as `ThumbnailDocument.png`.
    ///
    /// A path component is treated as an authored resource subdirectory. Resource lookup
    /// automatically falls back to the bundle root when processing flattened that directory.
    public static func resource(
        _ fileName: String,
        bundle: Bundle? = nil
    ) -> ImageReference {
        let path = fileName as NSString
        let lastComponent = path.lastPathComponent as NSString
        let pathExtension = lastComponent.pathExtension
        let resourceName = pathExtension.isEmpty
            ? String(lastComponent)
            : lastComponent.deletingPathExtension

        let directory = path.deletingLastPathComponent
        let subdirectory = directory.isEmpty || directory == "." ? nil : directory

        return .resource(
            name: resourceName,
            extension: pathExtension.isEmpty ? nil : pathExtension,
            subdirectory: subdirectory,
            bundle: bundle
        )
    }

    /// Compatibility spelling for the original named-image API.
    ///
    /// The old name was ambiguous about whether it meant an asset-catalog image or an ordinary
    /// bundle file. Existing callers continue to mean an asset-catalog image.
    @available(*, deprecated, renamed: "asset(_:bundle:)")
    public static func bundled(
        _ name: String,
        bundle: Bundle? = nil
    ) -> ImageReference {
        .asset(name, bundle: bundle)
    }

    public var isEmpty: Bool {
        switch self {
        case .none:
            true
        case .asset(let name, _):
            name.isEmpty
        case .resource(let name, _, _, _):
            name.isEmpty
        case .system(let name):
            name.isEmpty
        case .file(let url), .document(let url):
            url.path.isEmpty
        }
    }

    fileprivate var resourceURL: URL? {
        guard case let .resource(name, resourceExtension, subdirectory, bundle) = self else {
            return nil
        }

        return (bundle ?? .main).sbjResourceURL(
            name: name,
            extension: resourceExtension,
            subdirectory: subdirectory
        )
    }
}

import SwiftUI

#if canImport(ImageIO)
import ImageIO
#endif

public extension Image {
    init(_ reference: ImageReference) {
        switch reference {
        case .none:
            self = Image("")

        case .asset(let name, let bundle):
            // Preserve the established behavior of named framework UI imagery: asset-catalog
            // images are template images so semantic controls inherit their foreground style.
            self = Image(name, bundle: bundle)
                .renderingMode(.template)

        case .resource:
            #if canImport(ImageIO)
            if let url = reference.resourceURL,
               let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                self = Image(decorative: image, scale: 1)
            } else {
                self = Image("")
            }
            #else
            self = Image("")
            #endif

        case .system(let name):
            self = Image(systemName: name)

        case .file(let url):
            #if canImport(ImageIO)
            self = url.withSecurityScopedAccess { scopedURL in
                if let source = CGImageSourceCreateWithURL(scopedURL as CFURL, nil),
                   let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                    return Image(decorative: image, scale: 1)
                }
                return Image("")
            }
            #else
            self = Image("")
            #endif

        case .document(let url):
            #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
            if let image = SBJImageDocument.thumbnailImage(at: url, renderIfNeeded: false) {
                self = Image(uiImage: image)
            } else {
                self = Image("")
            }
            #else
            self = Image("")
            #endif
        }
    }
}

public extension Label where Title == Text, Icon == Image {
    init(_ title: LocalizedStringKey, image: ImageReference) {
        self = Label {
            Text(title)
        } icon: {
            Image(image)
        }
    }

    init(_ title: String, image: ImageReference) {
        self = Label {
            Text(title)
        } icon: {
            Image(image)
        }
    }
}

#if canImport(UIKit)
import UIKit

public extension ImageReference {
    var image: UIImage? {
        switch self {
        case .none:
            return nil

        case .asset(let name, let bundle):
            #if os(watchOS)
            return UIImage(named: name)
            #else
            return UIImage(named: name, in: bundle, compatibleWith: nil)
            #endif

        case .resource:
            guard let resourceURL else { return nil }
            return UIImage(contentsOfFile: resourceURL.path)

        case .system(let name):
            return UIImage(systemName: name)

        case .file(let url):
            return UIImage(url: url)

        case .document(let url):
            #if !os(watchOS) && !os(tvOS)
            return SBJImageDocument.thumbnailImage(at: url, renderIfNeeded: false)
            #else
            return nil
            #endif
        }
    }

    var data: Data? {
        image?.pngData()
    }
}
#endif
