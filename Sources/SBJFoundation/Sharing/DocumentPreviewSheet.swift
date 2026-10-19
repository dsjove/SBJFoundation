#if canImport(QuickLook) && canImport(UIKit) && !os(visionOS)
import SBJFileResources
import QuickLook
import SBJDataDefinition
import SwiftUI
import UIKit
import SBJLocalization

public struct DocumentPreviewController: UIViewControllerRepresentable {
    public let preview: URLAttachment

    public init(preview: URLAttachment) {
        self.preview = preview
    }

    public func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    public func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) { }

    public func makeCoordinator() -> Coordinator {
        Coordinator(url: preview.url, displayName: preview.displayName)
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

public struct DocumentPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    public let preview: URLAttachment

    public init(preview: URLAttachment) {
        self.preview = preview
    }

    public var body: some View {
        SBJSharePresentationHost { sharePresenter in
            NavigationStack {
                DocumentPreviewController(preview: preview)
                    .navigationTitle(preview.displayName)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { dismiss() }
                                .keyboardShortcut(.cancelAction)
                        }

                        ToolbarItemGroup(placement: .primaryAction) {
                            SBJImageButton(
                                SBJSymbology.open,
                                accessibilityLabel: "Open"
                            ) {
                                preview.url.open()
                            }

                            SBJShareButton(
                                presenter: sharePresenter,
                                prepare: { SBJSharePayload(preview.url) }
                            ) {
                                Image(symbol: SBJSymbology.share)
                                    .accessibilityLabel("Share")
                            }
                        }
                    }
            }
            .interactiveDismissDisabled()
        }
    }
}
#endif
