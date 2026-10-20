import SBJUIVocabulary
#if !os(watchOS) && !os(tvOS) && canImport(UIKit)
import LinkPresentation
import SBJDataDefinition
import UIKit

/// A fully prepared payload for one UIKit share presentation.
///
/// Prepare expensive representations before constructing this value. The share
/// presenter retains the exact payload for the lifetime of the activity sheet,
/// so SwiftUI recomputation never asks the caller to regenerate it.
@MainActor
public struct SBJSharePayload {
    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]?

    public init(
        activityItems: [Any],
        applicationActivities: [UIActivity]? = nil
    ) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
    }

    public init(
        _ activityItem: Any,
        applicationActivities: [UIActivity]? = nil
    ) {
        self.init(
            activityItems: [activityItem],
            applicationActivities: applicationActivities
        )
    }

    /// Shares an image as an image while also supplying Link Presentation
    /// metadata so the system share sheet can display the image preview.
    public init(
        _ image: UIImage,
        title: String? = nil,
        applicationActivities: [UIActivity]? = nil
    ) {
        self.init(
            activityItems: [SBJImageActivityItemSource(image: image, title: title)],
            applicationActivities: applicationActivities
        )
    }
}

/// `UIActivityViewController` can share a bare `UIImage`, but does not reliably
/// use it for the header preview. Supplying the same image through an activity
/// item source lets us attach `LPLinkMetadata` without changing the item that
/// receiving activities get.
private final class SBJImageActivityItemSource: NSObject, UIActivityItemSource {
    private let image: UIImage
    private let title: String?

    init(image: UIImage, title: String?) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        image
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}
#endif
