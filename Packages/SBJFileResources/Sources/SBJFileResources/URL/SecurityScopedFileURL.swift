import Foundation

/// A file URL together with the URL that grants access to it (often a
/// user-selected parent directory). Keep the authorization separate from
/// presentation metadata and retain its lease for the whole operation.
public struct SecurityScopedFileURL {
    public let url: URL
    private let authorizationURL: URL?

    public init(_ url: URL, accessing authorizationURL: URL? = nil) {
        self.url = url
        self.authorizationURL = authorizationURL
    }

    /// Starts security-scoped access until the returned lease is released.
    /// A false return from startAccessingSecurityScopedResource does not
    /// necessarily mean denial: unsandboxed and already-authorized URLs can
    /// be accessed without a new scope. Actual I/O must still handle errors.
    public func beginAccess() -> SecurityScopedFileURLLease {
        SecurityScopedFileURLLease(authorizationURL ?? url)
    }
}

/// A balanced security-scope lifetime for asynchronous readers such as AVPlayer.
/// Release the lease after the player has discarded its current item.
public final class SecurityScopedFileURLLease {
    private let accessURL: URL
    private let didStartAccess: Bool

    init(_ url: URL) {
        accessURL = url
        #if canImport(Darwin)
        didStartAccess = url.startAccessingSecurityScopedResource()
        #else
        didStartAccess = false
        #endif
    }

    deinit {
        #if canImport(Darwin)
        if didStartAccess { accessURL.stopAccessingSecurityScopedResource() }
        #endif
    }
}
