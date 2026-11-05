import Foundation

/// One user-authorized directory; media records only need paths relative to it.
/// Bookmark persistence remains owned by BookmarkedURLWithFallback.
public struct ScopedDirectory: Sendable {
    public let url: URL

    public init(_ url: URL) {
        self.url = url
    }

    public func file(at relativePath: String) throws -> ScopedFile {
        try ScopedFile(directory: self, relativePath: relativePath)
    }

    public func file(at url: URL) throws -> ScopedFile {
        let root = self.url.standardizedFileURL.pathComponents
        let child = url.standardizedFileURL.pathComponents
        guard child.count > root.count, Array(child.prefix(root.count)) == root else {
            throw ScopedFileError.outsideDirectory
        }
        return try file(at: child.dropFirst(root.count).joined(separator: "/"))
    }

    /// Hold this lease until asynchronous work (AVPlayer, etc.) is finished.
    public func beginAccess() -> SecurityScopedFileURLLease {
        SecurityScopedFileURLLease(url)
    }

    public func withAccess<T>(_ body: (URL) throws -> T) rethrows -> T {
        try url.withSecurityScopedAccess(body)
    }
}

public enum ScopedFileError: Error, LocalizedError {
    case invalidRelativePath
    case outsideDirectory

    public var errorDescription: String? {
        switch self {
        case .invalidRelativePath: "File path must be relative and cannot contain '.' or '..'."
        case .outsideDirectory: "The file is outside the authorized directory."
        }
    }
}

/// A relative path joined to its authorizing root. The full URL is derived,
/// never persisted by the media record. Symlink traversal is checked when used.
public struct ScopedFile: Sendable {
    public let directory: ScopedDirectory
    public let relativePath: String

    public init(directory: ScopedDirectory, relativePath: String) throws {
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.hasPrefix("/"), !relativePath.hasSuffix("/"),
              !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw ScopedFileError.invalidRelativePath
        }
        self.directory = directory
        self.relativePath = relativePath
    }

    public var url: URL { directory.url.appendingPathComponent(relativePath) }

    /// Verify the real filesystem path (including symlinks) before I/O.
    /// The source must exist for this check; do not use it to construct a new file.
    public func checkedURL() throws -> URL {
        let root = directory.url.resolvingSymlinksInPath().standardizedFileURL.path
        let candidate = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard candidate.hasPrefix(root + "/") else { throw ScopedFileError.outsideDirectory }
        return url
    }

    public func beginAccess() -> SecurityScopedFileURLLease { directory.beginAccess() }

    public func withAccess<T>(_ body: (URL) throws -> T) throws -> T {
        try directory.withAccess { _ in try body(checkedURL()) }
    }

    @MainActor
    @discardableResult
    public func open() -> Bool {
        guard (try? checkedURL()) != nil else { return false }
        return directory.withAccess { _ in url.open() }
    }

    /// Transitional interoperability for APIs accepting SecurityScopedFileURL.
    public var securityScopedURL: SecurityScopedFileURL {
        SecurityScopedFileURL(url, accessing: directory.url)
    }
}
