import Foundation

/// Persisted file location that retains its readable path when a security-scoped
/// bookmark cannot currently be resolved (for example, an ejected volume).
///
/// Resolving a bookmark does not itself grant enduring access. Callers should
/// use `withSecurityScopedAccess` for each synchronous filesystem operation.
public struct BookmarkedURLWithFallback {
    public let bookmarkKey: String
    public let pathKey: String
    private let defaults: UserDefaults

    public init(bookmarkKey: String, pathKey: String, defaults: UserDefaults = .standard) {
        self.bookmarkKey = bookmarkKey
        self.pathKey = pathKey
        self.defaults = defaults
    }

    /// The last known location, even when its volume is disconnected.
    public var fallbackURL: URL? {
        guard let path = defaults.string(forKey: pathKey), !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// Always saves the path first so a bookmark failure cannot erase the UI value.
    public func save(_ url: URL) throws {
        defaults.set(url.path, forKey: pathKey)
        // Do not let a prior selection's bookmark override the new path if
        // creating a bookmark for the new selection fails.
        defaults.removeObject(forKey: bookmarkKey)
        let data = try url.withSecurityScopedAccess { scopedURL in
            try scopedURL.bookmarkData(
                options: Self.creationOptions,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
        defaults.set(data, forKey: bookmarkKey)
    }

    /// Prefers the bookmark, but returns the stored path if it cannot resolve.
    /// Stale bookmarks are renewed when possible without discarding the fallback.
    public func resolve() -> URL? {
        guard let data = defaults.data(forKey: bookmarkKey) else { return fallbackURL }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: Self.resolutionOptions,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return fallbackURL }

        defaults.set(url.path, forKey: pathKey)
        if stale { try? save(url) }
        return url
    }

    /// Returns the authorized root without treating the display fallback as permission.
    public func scopedDirectory() -> ScopedDirectory? {
        guard let data = defaults.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let resolved = try? URL(
            resolvingBookmarkData: data,
            options: Self.resolutionOptions,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        defaults.set(resolved.path, forKey: pathKey)
        if stale { try? save(resolved) }
        return ScopedDirectory(resolved)
    }

    /// Re-attempt resolution after an external drive is connected.
    public func refresh() -> URL? { resolve() }

    private static var creationOptions: URL.BookmarkCreationOptions {
#if os(macOS) && !targetEnvironment(macCatalyst)
        [.withSecurityScope]
#else
        []
#endif
    }

    private static var resolutionOptions: URL.BookmarkResolutionOptions {
#if os(macOS) && !targetEnvironment(macCatalyst)
        [.withSecurityScope]
#else
        []
#endif
    }
}
