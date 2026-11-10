import Foundation
import SBJLocalization
#if DEBUG && targetEnvironment(macCatalyst)
import ObjectiveC.runtime
#endif
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

#if DEBUG && targetEnvironment(macCatalyst) && !WIDGET_TARGET
/// Experimental Finder selection for Catalyst debug builds only. AppKit is not
/// linked or imported: this works only if NSWorkspace is already available in
/// the process's Objective-C runtime. Failure means "use the UIKit fallback".
/// The Objective-C implementation returns Void, so a call is not confirmation
/// that Finder actually selected the file.
@MainActor
private func debugRevealInFinder(_ file: URL, directory: URL?) -> Bool {
    let attempt: () -> Bool = {
        guard let workspaceClass = NSClassFromString("NSWorkspace") else {
            NSLog("ShowInFinder: DEBUG NSWorkspace unavailable; falling back to folder")
            return false
        }
        let sharedSelector = NSSelectorFromString("sharedWorkspace")
        let revealSelector = NSSelectorFromString("activateFileViewerSelectingURLs:")
        guard let sharedMethod = class_getClassMethod(workspaceClass, sharedSelector),
              let revealMethod = class_getInstanceMethod(workspaceClass, revealSelector) else {
            NSLog("ShowInFinder: DEBUG Finder selectors unavailable; falling back to folder")
            return false
        }

        typealias SharedWorkspaceIMP = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>
        typealias RevealFileIMP = @convention(c) (AnyObject, Selector, NSArray) -> Void
        let getWorkspace = unsafeBitCast(method_getImplementation(sharedMethod), to: SharedWorkspaceIMP.self)
        let reveal = unsafeBitCast(method_getImplementation(revealMethod), to: RevealFileIMP.self)
        let workspace = getWorkspace(workspaceClass, sharedSelector).takeUnretainedValue()
        NSLog("ShowInFinder: DEBUG attempting NSWorkspace selection: %@", file.path)
        reveal(workspace, revealSelector, [file] as NSArray)
        return true
    }

    if let directory {
        return directory.withSecurityScopedAccess { _ in attempt() }
    }
    return file.withSecurityScopedAccess { _ in attempt() }
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
        #if DEBUG && targetEnvironment(macCatalyst)
        if debugRevealInFinder(self, directory: directory) { return }
        #endif
        // Keep the fallback behavior: Catalyst opens the containing
        // folder when runtime selection is unavailable. Resource-value lookup
        // occurs under the lease.
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
