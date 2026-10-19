import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#elseif os(watchOS)
import WatchKit
#endif

/// Platform URL behavior used by help and other clients.
///
/// This deliberately does not use SwiftUI's `openURL` environment. Keeping the
/// behavior on `URL` makes it available to non-SwiftUI callers and preserves the
/// platform-opening path used by existing applications.
@MainActor
public extension URL {
    var isValidURL: Bool {
        guard !absoluteString.isEmpty, scheme != nil else { return false }

#if canImport(UIKit)
#if WIDGET_TARGET
        return true
#else
        return UIApplication.shared.canOpenURL(self)
#endif
#elseif canImport(AppKit)
        return true
#elseif os(watchOS)
        return true
#else
        return true
#endif
    }

    @discardableResult
    static func open(_ urlString: String) -> URL? {
        let url = URL(string: urlString)
        open(url)
        return url
    }

    static func open(_ url: URL?) {
        url?.open()
    }

    func open() {
#if canImport(UIKit)
#if !WIDGET_TARGET
        UIApplication.shared.open(self, options: [:], completionHandler: nil)
#endif
#elseif canImport(AppKit)
        NSWorkspace.shared.open(self)
#elseif os(watchOS)
		WKApplication.shared().openSystemURL(self)
#endif
    }
}


