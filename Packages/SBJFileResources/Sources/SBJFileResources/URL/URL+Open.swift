import Foundation
import SBJLocalization
#if os(watchOS)
import WatchKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit) && !os(watchOS)
/// Owns the security scope until UIKit reports that the external open request
/// has completed. The object only transfers ownership across the callback;
/// no mutable state is accessed across threads.
private final class FinderOpenHandoff: @unchecked Sendable {
    private let scope: SecurityScopedFileURLLease

    init(file: URL, directory: URL?) {
        scope = SecurityScopedFileURL(file, accessing: directory).beginAccess()
    }

    func complete(accepted: Bool, folder: URL) {
        if !accepted {
            NSLog("ShowInFinder: UIKit rejected opening folder: %@", folder.path)
        }
        // Retain the lease until after UIKit's completion callback.
        withExtendedLifetime(scope) {}
    }
}
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

    /// Reveal a file in Finder on macOS, otherwise request its enclosing folder.
    /// The public API is intentionally synchronous for existing callers. UIKit's
    /// open is asynchronous: on Catalyst the directory security scope must remain
    /// active until the completion callback, not merely until request submission.
    func showInFinder(directory: URL? = nil) {
        guard isFileURL, Self.hasFinder else { return }
#if os(macOS)
        if let directory {
            directory.withSecurityScopedAccess { _ in
                NSWorkspace.shared.activateFileViewerSelecting([self])
            }
        } else {
            withSecurityScopedAccess { _ in
                NSWorkspace.shared.activateFileViewerSelecting([self])
            }
        }
#elseif canImport(UIKit) && !WIDGET_TARGET
        // Do not change the fallback behavior: Catalyst opens the containing
        // folder, not the file selection, because AppKit's Finder selection API
        // is unavailable here. Resource-value lookup occurs under the lease.
        let handoff = FinderOpenHandoff(file: self, directory: directory)
        let isDirectory = (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory
        let folder = (isDirectory ?? (hasDirectoryPath || pathExtension.isEmpty))
            ? self : deletingLastPathComponent()
        NSLog("ShowInFinder: Catalyst requesting folder: %@ (file: %@)", folder.path, path)
        UIApplication.shared.open(folder, options: [:]) { [handoff] accepted in
            handoff.complete(accepted: accepted, folder: folder)
        }
#else
        if let directory {
            directory.withSecurityScopedAccess { _ in self.openFolder() }
        } else {
            withSecurityScopedAccess { _ in self.openFolder() }
        }
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
