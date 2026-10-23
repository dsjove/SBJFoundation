#if !os(watchOS) && !os(tvOS) && canImport(UIKit)
import SwiftUI
import UIKit

/// Low-level SwiftUI bridge to `UIActivityViewController`.
///
/// Most callers should use `SBJShareButton` under an
/// `SBJSharePresentationHost`; use this directly only when presentation state is
/// already owned and stabilized by the caller.
@MainActor
public struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    let dismissed: (() -> Void)?

    public init(
        activityItems: [Any],
        applicationActivities: [UIActivity]? = nil,
        dismissed: (() -> Void)? = nil
    ) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
        self.dismissed = dismissed
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        if let dismissed {
            controller.completionWithItemsHandler = { _, _, _, _ in
                DispatchQueue.main.async {
                    dismissed()
                }
            }
        }
        return controller
    }

    public func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {
    }
}
#endif
