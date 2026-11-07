import Foundation
import SBJLocalization
#if os(watchOS)
import WatchKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Platform URL behavior used by help and other clients.
///
/// This deliberately does not use SwiftUI's `openURL` environment. Keeping the
/// behavior on `URL` makes it available to non-SwiftUI callers and preserves the
/// platform-opening path used by existing applications.
@MainActor
public extension URL {
    /// Historical behavior: on UIKit this is handler availability (not syntactic
    /// validity); on AppKit it only requires a URL scheme. Preserve callers'
    /// existing semantics, including UIApplication.canOpenURL restrictions on
    /// non-whitelisted custom schemes.
    ///
    /// PROPOSAL (not applied): split into isSyntacticallyValidURL and canBeOpened.
    /// An http(s) URL should have a host; a file URL should have a path.
    /// canOpenURL answers whether iOS permits querying a handler, not whether
    /// a URL is well-formed or whether a removable file is presently mounted.
    var isValidURL: Bool {
        guard !absoluteString.isEmpty, scheme != nil else { return false }
#if os(watchOS)
        return true
#elseif canImport(UIKit)
    #if WIDGET_TARGET
        return true
    #else
        return UIApplication.shared.canOpenURL(self)
    #endif
#elseif canImport(AppKit)
        return true
#else
        return true
#endif
    }

    /// Opens this directory or the containing folder of a file.
    /// A missing extensionless path cannot be distinguished reliably from a folder.
    func openFolder() {
        guard isFileURL else { return }
        let isDirectory = (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory
        let folder = (isDirectory ?? (hasDirectoryPath || pathExtension.isEmpty))
            ? self : deletingLastPathComponent()
        folder.open()
    }

    /// Whether the current platform provides a native Finder handoff.
    static var hasFinder: Bool { ProcessInfo.isAnyMac }

    /// Reveal a file in Finder on macOS, otherwise open its containing folder.
    /// Security-scoped access is retained for the duration of the handoff.
    func showInFinder(directory: URL? = nil) {
        guard isFileURL, Self.hasFinder else { return }
        let reveal = {
#if os(macOS)
            NSWorkspace.shared.activateFileViewerSelecting([self])
#else
            self.openFolder()
#endif
        }
        if let directory {
            directory.withSecurityScopedAccess { _ in reveal() }
        } else {
            withSecurityScopedAccess { _ in reveal() }
        }
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

    /// Opens while the selected directory is security-scoped. On UIKit, the
    /// result indicates request submission, not asynchronous completion.
    @discardableResult
    func open(accessing directory: URL?) -> Bool {
        guard let directory else { return open() }
        return directory.withSecurityScopedAccess { _ in open() }
    }

    @discardableResult
    func open() -> Bool {
#if os(watchOS)
		WKApplication.shared().openSystemURL(self)
        return true
#elseif canImport(UIKit)
    #if !WIDGET_TARGET
        UIApplication.shared.open(self, options: [:], completionHandler: nil)
        return true // Request queued; UIKit reports completion asynchronously.
    #else
        return false
    #endif
#elseif canImport(AppKit)
        return NSWorkspace.shared.open(self)
#else
        return false
#endif
    }
}
