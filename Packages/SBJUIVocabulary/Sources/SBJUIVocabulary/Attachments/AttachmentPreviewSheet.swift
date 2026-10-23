#if canImport(QuickLook) && canImport(UIKit) && !os(visionOS)
import QuickLook
import SwiftUI
import UIKit
import SBJLocalization
import SBJFileResources

public struct AttachmentPreviewSheet: UIViewControllerRepresentable {
    public let url: URL
    public let displayName: String

    public init(url: URL, displayName: String) {
        self.url = url
        self.displayName = displayName
    }

    public func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    public func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) { }

    public func makeCoordinator() -> Coordinator {
        Coordinator(url: url, displayName: displayName)
    }

    public final class Coordinator: NSObject, QLPreviewControllerDataSource {
        private let item: URLPreviewItem

        init(url: URL, displayName: String) {
            self.item = URLPreviewItem(url: url, displayName: displayName)
        }

        public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            item
        }
    }

    private final class URLPreviewItem: NSObject, QLPreviewItem {
        let url: URL
        let displayName: String

        init(url: URL, displayName: String) {
            self.url = url
            self.displayName = displayName
        }

        var previewItemURL: URL? { url }
        var previewItemTitle: String? { displayName }
    }
}

#endif
