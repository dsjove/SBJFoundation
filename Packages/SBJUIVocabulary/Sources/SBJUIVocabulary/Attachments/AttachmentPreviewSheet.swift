#if (canImport(QuickLook) && canImport(UIKit) && !os(visionOS)) || (os(macOS) && canImport(QuickLookUI))
import SwiftUI
#if os(macOS)
import AppKit
import QuickLookUI
#else
import UIKit
import QuickLook
#endif

/// A single Quick Look preview API for macOS and iOS.
///
/// Presentation (sheet, cover, navigation) belongs to the caller. This view
/// only hosts the native Quick Look component for the selected attachment.
@MainActor
public struct AttachmentPreviewSheet: View {
    public let url: URL
    public let displayName: String

    public init(url: URL, displayName: String) {
        self.url = url
        self.displayName = displayName
    }

    public var body: some View {
        #if os(macOS)
        NativeAttachmentPreview(url: url)
        #else
        NativeAttachmentPreview(url: url, displayName: displayName)
        #endif
    }
}

#if os(macOS)
/// Only the AppKit bridge is platform-specific; all callers share the same view.
private struct NativeAttachmentPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        if let view = QLPreviewView(frame: .zero, style: .normal) {
            view.previewItem = url as NSURL
            return view
        }
        let view = QLPreviewView()
        view.previewItem = url as NSURL
        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        view.previewItem = url as NSURL
    }
}
#else
/// Quick Look on iOS requires a controller and data source.
private struct NativeAttachmentPreview: UIViewControllerRepresentable {
    let url: URL
    let displayName: String

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        // A SwiftUI view may be reused for a different attachment.
        if context.coordinator.update(url: url, displayName: displayName) {
            controller.reloadData()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, displayName: displayName)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        private var item: URLPreviewItem

        init(url: URL, displayName: String) {
            item = URLPreviewItem(url: url, displayName: displayName)
        }

        func update(url: URL, displayName: String) -> Bool {
            guard item.url != url || item.displayName != displayName else { return false }
            item = URLPreviewItem(url: url, displayName: displayName)
            return true
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
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
#endif
