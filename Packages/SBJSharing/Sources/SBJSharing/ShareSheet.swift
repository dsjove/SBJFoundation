#if !os(watchOS) && !os(tvOS) && (canImport(UIKit) || canImport(AppKit))
import SwiftUI

/// Native share picker bridge; prefer SBJSharePresentationHost for coordinated presentation.
@MainActor
public struct ShareSheet {
    let activityItems: [Any]
    let applicationActivities: [SBJShareActivity]?
    let dismissed: (() -> Void)?

    public init(activityItems: [Any], applicationActivities: [SBJShareActivity]? = nil, dismissed: (() -> Void)? = nil) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
        self.dismissed = dismissed
    }
}

#if canImport(UIKit)
import UIKit
extension ShareSheet: UIViewControllerRepresentable {
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        if let dismissed {
            controller.completionWithItemsHandler = { _, _, _, _ in
                DispatchQueue.main.async { dismissed() }
            }
        }
        return controller
    }
    public func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#elseif canImport(AppKit)
import AppKit
extension ShareSheet: NSViewRepresentable {
    public func makeCoordinator() -> Coordinator { Coordinator(dismissed: dismissed, extraServices: applicationActivities) }

    public func makeNSView(context: Context) -> NSView {
        let view = SBJPanelAnchor(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        let picker = NSSharingServicePicker(items: activityItems)
        picker.delegate = context.coordinator
        context.coordinator.picker = picker
        view.onAttach = { [weak coordinator = context.coordinator] view in
            coordinator?.picker?.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
        return view
    }

    public func updateNSView(_ view: NSView, context: Context) {}

    public final class Coordinator: NSObject, NSSharingServicePickerDelegate {
        var picker: NSSharingServicePicker?
        private let dismissed: (() -> Void)?
        private let extraServices: [NSSharingService]?

        init(dismissed: (() -> Void)?, extraServices: [NSSharingService]?) {
            self.dismissed = dismissed
            self.extraServices = extraServices
        }

        public func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposed: [NSSharingService]) -> [NSSharingService] {
            proposed + (extraServices ?? [])
        }

        public func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
            dismissed?()
        }
    }
}
#endif
#endif
