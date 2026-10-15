import Foundation
import UniformTypeIdentifiers

/// Errors produced while validating `FileWrapper` values loaded from disk.
///
/// `FileWrapper` exposes several Objective-C APIs whose preconditions are enforced by
/// `NSException` rather than Swift errors. In particular, asking a directory wrapper for
/// `regularFileContents` (or a regular-file wrapper for `fileWrappers`) terminates the process.
/// Use these validated accessors at disk/package boundaries so malformed or unexpected file
/// layouts stay in Swift's error model.
public enum SBJFileWrapperReadError: Error, Sendable, Equatable {
    case expectedRegularFile(String?)
    case expectedDirectory(String?)
    case unreadableRegularFile(String?)
    case unreadableDirectory(String?)
    case unsupportedWrapper(String?)
}

public extension FileWrapper {
    /// Returns regular-file bytes only after verifying the wrapper kind.
    ///
    /// This method is safe to use with untrusted disk structure: it never invokes
    /// `regularFileContents` for a non-regular wrapper.
    func sbjRegularFileContents() throws -> Data {
        guard isRegularFile else {
            throw SBJFileWrapperReadError.expectedRegularFile(preferredFilename ?? filename)
        }
        guard let data = regularFileContents else {
            throw SBJFileWrapperReadError.unreadableRegularFile(preferredFilename ?? filename)
        }
        return data
    }

    /// Returns directory children only after verifying the wrapper kind.
    ///
    /// This method is safe to use with untrusted disk structure: it never invokes
    /// `fileWrappers` for a non-directory wrapper.
    func sbjDirectoryContents() throws -> [String: FileWrapper] {
        guard isDirectory else {
            throw SBJFileWrapperReadError.expectedDirectory(preferredFilename ?? filename)
        }
        guard let children = fileWrappers else {
            throw SBJFileWrapperReadError.unreadableDirectory(preferredFilename ?? filename)
        }
        return children
    }
}

/// Encoded resource content with its Foundation content type.
///
/// This is intentionally separate from `SBJResourceID`: the ID is semantic
/// identity while this value is the transport/storage payload.
///
/// Resources may be either ordinary files or directory/package content. `data` remains the
/// transport representation for compatibility: regular files store their bytes directly and
/// directories store `FileWrapper.serializedRepresentation`. `storageRepresentation` records
/// the actual on-disk shape so a package whose UTType is unavailable can still round-trip as a
/// directory instead of being flattened into a regular file.
public struct SBJResourceContent: Sendable, Equatable {
    public enum StorageRepresentation: Sendable, Equatable {
        case regularFile
        case directory
    }

    public let data: Data
    public let contentType: UTType
    public let storageRepresentation: StorageRepresentation

    public init(data: Data, contentType: UTType) {
        self.data = data
        self.contentType = contentType

        // Package types created in memory historically arrive as FileWrapper serialized data.
        // Record that shape when it can be positively identified; otherwise keep ordinary data
        // as a regular file. Disk reads do not rely on UTType inference and set the shape from
        // the actual wrapper instead.
        if contentType.conforms(to: .package),
           let wrapper = FileWrapper(serializedRepresentation: data),
           wrapper.isDirectory {
            self.storageRepresentation = .directory
        } else {
            self.storageRepresentation = .regularFile
        }
    }

    private init(
        data: Data,
        contentType: UTType,
        storageRepresentation: StorageRepresentation
    ) {
        self.data = data
        self.contentType = contentType
        self.storageRepresentation = storageRepresentation
    }

    /// Filename extension used when persisting this resource.
    public var storageFilenameExtension: String {
        contentType.preferredFilenameExtension ?? "data"
    }

    /// Creates the appropriate file wrapper for this resource.
    ///
    /// Directory/package shape is driven by the shape captured at load/creation time rather
    /// than solely by UTType. This is important for application-defined packages whose type may
    /// not be registered in every process that reads them.
    public func storageFileWrapper() -> FileWrapper {
        switch storageRepresentation {
        case .regularFile:
            return FileWrapper(regularFileWithContents: data)
        case .directory:
            // A directory representation can only be created when the bytes successfully decode
            // as a directory wrapper. Keep a defensive fallback so this API itself never crashes.
            if let wrapper = FileWrapper(serializedRepresentation: data), wrapper.isDirectory {
                return wrapper
            }
            return FileWrapper(regularFileWithContents: data)
        }
    }

    /// Resolves a stored resource's content type. Callers may supply the concrete type when the
    /// filename extension is unavailable or not registered in the current process.
    public static func storageContentType(forFilename filename: String, fallback: UTType? = nil) -> UTType {
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        return fallback ?? UTType(filenameExtension: ext) ?? .data
    }

    /// Reconstitutes resource content from a regular-file or directory/package wrapper.
    ///
    /// The wrapper kind is validated before invoking any kind-specific Foundation property, so
    /// unexpected disk structure fails as `nil` rather than raising an Objective-C exception.
    /// Directory shape is preserved even when the filename's UTType is unknown.
    public init?(
        storageFileWrapper wrapper: FileWrapper,
        filename: String,
        fallbackContentType: UTType? = nil
    ) {
        if wrapper.isRegularFile {
            let type = Self.storageContentType(forFilename: filename, fallback: fallbackContentType)
            guard let storedData = try? wrapper.sbjRegularFileContents() else { return nil }
            self.init(
                data: storedData,
                contentType: type,
                storageRepresentation: .regularFile
            )
            return
        }

        if wrapper.isDirectory {
            // The physical wrapper shape is authoritative here. A host application may embed
            // an application-defined package without registering its extension with LaunchServices
            // (for example `.sbjimage`). In that case UTType(filenameExtension:) can resolve to a
            // dynamic non-package type, which makes package consumers reject a valid directory.
            // Reconstruct a package-conforming type from the extension whenever the supplied/found
            // type does not already preserve package semantics.
            let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
            let inferred = Self.storageContentType(forFilename: filename, fallback: fallbackContentType)
            let type: UTType
            if inferred.conforms(to: .package) {
                type = inferred
            } else if !ext.isEmpty, let packageType = UTType(filenameExtension: ext, conformingTo: .package) {
                type = packageType
            } else {
                type = .package
            }

            guard let storedData = wrapper.serializedRepresentation else { return nil }
            self.init(
                data: storedData,
                contentType: type,
                storageRepresentation: .directory
            )
            return
        }

        return nil
    }
}

#if canImport(ImageIO)
import ImageIO

public extension SBJResourceContent {
    /// Reconstructs image resource metadata from encoded image bytes.
    ///
    /// This is primarily useful for persisted models that historically stored
    /// only the encoded image `Data`. The encoded format is discovered from the
    /// image source instead of being guessed by the caller.
    init?(imageData data: Data) {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let typeIdentifier = CGImageSourceGetType(source),
            let contentType = UTType(typeIdentifier as String)
        else {
            return nil
        }

        self.init(data: data, contentType: contentType)
    }
}
#endif
