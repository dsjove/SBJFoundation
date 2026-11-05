#if !os(watchOS) && !os(tvOS) && (canImport(UIKit) || canImport(AppKit))
import Foundation
import SBJLocalization
#if canImport(UIKit)
import UIKit
import LinkPresentation
#elseif canImport(AppKit)
import AppKit
#endif

/// Retains the prepared share items throughout one presentation.
@MainActor
public struct SBJSharePayload {
    public let activityItems: [Any]
    public let applicationActivities: [SBJShareActivity]?

    public init(activityItems: [Any], applicationActivities: [SBJShareActivity]? = nil) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
    }

    public init(_ activityItem: Any, applicationActivities: [SBJShareActivity]? = nil) {
        self.init(activityItems: [activityItem], applicationActivities: applicationActivities)
    }

    public init(_ image: SBJImage, title: String? = nil, applicationActivities: [SBJShareActivity]? = nil) {
        #if canImport(UIKit)
        self.init(activityItems: [SBJImageActivityItemSource(image: image, title: title)], applicationActivities: applicationActivities)
        #else
        self.init(activityItems: [image], applicationActivities: applicationActivities)
        #endif
    }
}

#if canImport(UIKit)
/// UIKit needs an activity item source for the share sheet's image header metadata.
private final class SBJImageActivityItemSource: NSObject, UIActivityItemSource {
    private let image: SBJImage
    private let title: String?

    init(image: SBJImage, title: String?) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any { image }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? { image }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}
#endif
#endif
