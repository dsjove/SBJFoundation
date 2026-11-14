import SBJUIVocabulary
import SBJLocalization
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import UniformTypeIdentifiers
import SBJFileResources
#if canImport(UIKit) || canImport(AppKit)

public extension SBJResourceContent {
    /// Decodes ordinary image content, or resolves an SBJ image document to its persisted thumbnail cache.
    var sbjImage: SBJImage? {
#if !os(watchOS)
        if let document = try? SBJImageDocument(resourceContent: self) {
            return document.thumbnailImage(renderIfNeeded: false)
        }
#endif
        guard contentType.conforms(to: .image) else { return nil }
        return SBJImage(data: data)
    }
}
#endif
