#if canImport(UIKit)
import Foundation
import CoreLocation
import UniformTypeIdentifiers
import UIKit
#if canImport(PencilKit)
import PencilKit
#endif

/// A self-contained non-destructive image package.
///
/// The encoded source and edit recipe are authoritative. Thumbnail and/or fully rendered
/// derivatives may be persisted as disposable caches. The source image is only the fallback
/// when a requested rendered derivative cannot be produced.
public struct SBJImageDocument: Sendable, Equatable {
    /// Identifies the on-disk package schema. This is not a Uniform Type Identifier.
    /// Apps may optionally register `.sbjimage` as a standalone document type; embedding apps do not need to.
    public static let formatIdentifier = "com.softwarebyjove.image-document"
    public static let packageExtension = "sbjimage"

    public static var contentType: UTType {
		UTType(
			filenameExtension: packageExtension,
			conformingTo: .package
		)!
	}

    private static let thumbnailMaximumPixelDimension: CGFloat = 512

    public struct RenderCache: OptionSet, SBJFoundationType, Sendable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// Persist a small rendered derivative for document browsers and thumbnail providers.
        public static let thumbnail = Self(rawValue: 1 << 0)

        /// Persist the fully rendered edited image for Quick Look/full-preview consumers.
        public static let rendered = Self(rawValue: 1 << 1)

        /// Persist both supported rendered derivatives.
        public static let all: Self = [.thumbnail, .rendered]
    }

    private var source: SBJResourceContent
    public var location: CLLocation?
    private var edits: PhotoEditResult
    private var renderCache: RenderCache
    private var thumbnail: SBJResourceContent?
    private var rendered: SBJResourceContent?

    /// Creates a document from an immutable encoded source image.
    ///
    /// Use `renderCache` to choose which disposable rendered derivatives are persisted.
    /// The default stores only the bounded thumbnail cache, matching the historical behavior.
    public init(
        source: SBJResourceContent,
        location: CLLocation? = nil,
        renderCache: RenderCache = .thumbnail
    ) {
        self.source = source
        self.location = location
        let size = source.uiImage?.size ?? .init(width: 1, height: 1)
        self.edits = .init(geometry: .init(crop: .init(option: .none, sourceSize: size)))
        self.renderCache = renderCache
        self.thumbnail = nil
        self.rendered = nil
        rebuildRenderCache(options: .default)
    }

    /// Opens an image-document package from disk.
    public init(fileURL: URL) throws {
        self = try fileURL.withSecurityScopedAccess {
            try Self(fileWrapper: FileWrapper(url: $0, options: []))
        }
    }

    /// Fast disk path for thumbnail providers. Returns the thumbnail component
    /// already stored in the package, or `nil` when the document has no thumbnail.
    /// No source-image fallback or rendering is performed here; the host thumbnail
    /// provider owns its fallback behavior.
    public static func thumbnailURL(in fileURL: URL) -> URL? {
        fileURL.withSecurityScopedAccess { packageURL in
            guard let manifest = try? manifest(at: packageURL),
                  let descriptor = manifest.thumbnail,
                  let url = componentURL(in: packageURL, path: descriptor.path),
                  FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            return url
        }
    }

    /// Resolves a thumbnail image for this package.
    ///
    /// When `renderIfNeeded` is `false`, only a persisted thumbnail cache is used.
    /// When it is `true`, a missing cache may be rendered from the document source/edit state.
    public static func thumbnailImage(
        at fileURL: URL,
        renderIfNeeded: Bool,
        options: PhotoEditorOptions = .default
    ) -> UIImage? {
        if let url = thumbnailURL(in: fileURL),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }
        guard renderIfNeeded else { return nil }
        return fileURL.withSecurityScopedAccess { packageURL in
            guard let document = try? SBJImageDocument(
                fileWrapper: FileWrapper(url: packageURL, options: [])
            ) else {
                return nil
            }
            return document.thumbnailImage(renderIfNeeded: true, options: options)
        }
    }

    /// Fast disk path for full-preview consumers. Returns the fully rendered component
    /// already stored in the package, or `nil` when that cache option is disabled or unavailable.
    static func renderedURL(in fileURL: URL) -> URL? {
        fileURL.withSecurityScopedAccess { packageURL in
            guard let manifest = try? manifest(at: packageURL),
                  let descriptor = manifest.rendered,
                  let url = componentURL(in: packageURL, path: descriptor.path),
                  FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            return url
        }
    }

    /// Resolves a fully rendered image for this package.
    ///
    /// When `renderIfNeeded` is `false`, only a persisted rendered cache is used.
    /// When it is `true`, a missing cache may be rendered from the document source/edit state.
    public static func renderedImage(
        at fileURL: URL,
        renderIfNeeded: Bool,
        options: PhotoEditorOptions = .default
    ) -> UIImage? {
        if let url = renderedURL(in: fileURL),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }
        guard renderIfNeeded else { return nil }
        return fileURL.withSecurityScopedAccess { packageURL in
            guard let document = try? SBJImageDocument(
                fileWrapper: FileWrapper(url: packageURL, options: [])
            ) else {
                return nil
            }
            return document.renderedImage(renderIfNeeded: true, options: options)
        }
    }

    /// Opens a serialized image-document package.
    init(serializedRepresentation data: Data) throws {
        guard let wrapper = FileWrapper(serializedRepresentation: data) else {
            throw Error.invalidPackage
        }
        try self.init(fileWrapper: wrapper)
    }

    /// Opens this package from generic resource content. The host application owns the
    /// concrete UTType; the framework recognizes its own package schema from the bytes.
    public init(resourceContent: SBJResourceContent) throws {
        guard resourceContent.contentType.conforms(to: .package) else {
            throw Error.invalidPackage
        }
        try self.init(serializedRepresentation: resourceContent.data)
    }

    public enum Error: Swift.Error {
        case invalidPackage
        case missingSource
        case invalidComponent
    }

    private struct Manifest: Codable {
        struct Component: Codable {
            var path: String
            var contentType: String
        }

        struct Markup: Codable {
            var path: String
            var contentType: String
            var canvasSize: PhotoMarkupCanvasSize
            var coordinateSpace: PhotoMarkupCoordinateSpace
        }

        var format: String
        var source: Component
        var displayName: String
        var description: String
        var geometry: Component
        var color: Component
        var location: Component?
        var markup: Markup?

        var renderCache: RenderCache
        var thumbnail: Component?
        var rendered: Component?
    }
    
    private init(
        source: SBJResourceContent,
        location: CLLocation?,
        edits: PhotoEditResult,
        renderCache: RenderCache,
        thumbnail: SBJResourceContent?,
        rendered: SBJResourceContent?
    ) {
        self.source = source
        self.location = location
        self.edits = edits
        self.renderCache = renderCache
        self.thumbnail = thumbnail
        self.rendered = rendered
    }


    private static func manifest(at packageURL: URL) throws -> Manifest {
        let data = try Data(contentsOf: packageURL.appendingPathComponent("manifest.json"))
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        guard manifest.format == Self.formatIdentifier else {
            throw Error.invalidPackage
        }
        return manifest
    }

    private static func componentURL(in packageURL: URL, path: String) -> URL? {
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        guard !components.isEmpty,
              !path.hasPrefix("/"),
              components.allSatisfy({ $0 != "." && $0 != ".." }) else {
            return nil
        }
        return components.reduce(packageURL) { url, component in
            url.appendingPathComponent(String(component), isDirectory: false)
        }
    }

    private init(fileWrapper: FileWrapper) throws {
        guard fileWrapper.isDirectory,
              let root = try? fileWrapper.sbjDirectoryContents(),
              let manifestWrapper = root["manifest.json"],
              manifestWrapper.isRegularFile,
              let manifestData = try? manifestWrapper.sbjRegularFileContents() else {
            throw Error.invalidPackage
        }

        let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        guard manifest.format == Self.formatIdentifier else {
            throw Error.invalidPackage
        }

        func data(at path: String) -> Data? {
            var current = fileWrapper
            for part in path.split(separator: "/") {
                guard current.isDirectory,
                      let children = try? current.sbjDirectoryContents(),
                      let next = children[String(part)] else {
                    return nil
                }
                current = next
            }
            guard current.isRegularFile else { return nil }
            return try? current.sbjRegularFileContents()
        }

        guard let sourceData = data(at: manifest.source.path),
              let sourceType = UTType(manifest.source.contentType) else {
            throw Error.missingSource
        }
        guard let geometryData = data(at: manifest.geometry.path),
              let colorData = data(at: manifest.color.path) else {
            throw Error.invalidComponent
        }

        let source = SBJResourceContent(data: sourceData, contentType: sourceType)
        let geometry = try JSONDecoder().decode(PhotoEditGeometry.self, from: geometryData)
        let color = try JSONDecoder().decode(PhotoColorAdjustments.self, from: colorData)

        let markup: PhotoMarkup?
        if let descriptor = manifest.markup,
           let markupData = data(at: descriptor.path) {
            markup = .init(
                data: markupData,
                contentTypeIdentifier: descriptor.contentType,
                canvasSize: descriptor.canvasSize,
                coordinateSpace: descriptor.coordinateSpace
            )
        } else {
            markup = nil
        }

        let thumbnail: SBJResourceContent?
        if let descriptor = manifest.thumbnail,
           let thumbnailData = data(at: descriptor.path),
           let thumbnailType = UTType(descriptor.contentType) {
            thumbnail = .init(data: thumbnailData, contentType: thumbnailType)
        } else {
            thumbnail = nil
        }

        let rendered: SBJResourceContent?
        if let descriptor = manifest.rendered,
           let renderedData = data(at: descriptor.path),
           let renderedType = UTType(descriptor.contentType) {
            rendered = .init(data: renderedData, contentType: renderedType)
        } else {
            rendered = nil
        }

        let location: CLLocation?
        if let descriptor = manifest.location,
           let locationData = data(at: descriptor.path) {
            location = try JSONDecoder().decode(LocationJSON.self, from: locationData).location
        } else {
            location = nil
        }

        self.init(
            source: source,
            location: location,
            edits: .init(
                displayName: manifest.displayName,
                description: manifest.description,
                geometry: geometry,
                color: color,
                markup: markup
            ),
            renderCache: manifest.renderCache,
            thumbnail: thumbnail,
            rendered: rendered
        )
    }

    /// Resolves this document's thumbnail according to the caller's cache-miss policy.
    public func thumbnailImage(
        renderIfNeeded: Bool,
        options: PhotoEditorOptions = .default
    ) -> UIImage? {
        if let image = thumbnail?.uiImage { return image }
        guard renderIfNeeded else { return nil }
        return makeThumbnail(options: options)?.uiImage
    }

    /// Resolves this document's full rendered image according to the caller's cache-miss policy.
    /// The immutable source is used only after an attempted render fails.
    public func renderedImage(
        renderIfNeeded: Bool,
        options: PhotoEditorOptions = .default
    ) -> UIImage? {
        if let image = rendered?.uiImage { return image }
        guard renderIfNeeded else { return nil }
        return renderedContent(options: options)?.uiImage ?? source.uiImage
    }

    /// Serializes the complete package, including the selected rendered caches.
    var serializedRepresentation: Data {
        get throws {
            guard let data = try makeFileWrapper().serializedRepresentation else {
                throw Error.invalidPackage
            }
            return data
        }
    }

    /// Writes the complete package atomically.
    public func write(to url: URL) throws {
        try makeFileWrapper().write(to: url, options: .atomic, originalContentsURL: nil)
    }

    /// Encodes this document as resource content using the package type known in this code path.
    /// `contentType` is resolved from the `.sbjimage` extension as a package. If a host app
    /// exports that extension, Uniform Type Identifiers resolves to the app's declared type;
    /// otherwise this remains a local dynamic type and requires no Info.plist declaration.
    public func resourceContent(contentType: UTType = Self.contentType) -> SBJResourceContent? {
        guard let data = try? serializedRepresentation else { return nil }
        return .init(data: data, contentType: contentType)
    }

    // MARK: - Editor integration

    /// Internal editor input. Keeping the stored state private prevents clients from
    /// coordinating source/edit/cache mutations themselves.
    var editorInput: (source: SBJResourceContent, edits: PhotoEditResult) {
        (source, edits)
    }

    /// Applies an edit result atomically and rebuilds all selected rendered caches in the same call.
    func applying(
        _ edits: PhotoEditResult,
        options: PhotoEditorOptions = .default
    ) -> Self {
        var copy = self
        copy.edits = edits
        copy.rebuildRenderCache(options: options)
        return copy
    }

    // MARK: - Rendering

    /// Renders the supported current state. Reserved perspective/skew state is not yet applied.
    private func renderedContent(options: PhotoEditorOptions) -> SBJResourceContent? {
#if canImport(PencilKit)
        let drawing: Any? = edits.markup?.pencilKitDrawing
#else
        let drawing: Any? = nil
#endif
        return PhotoEditRenderer.render(
            resource: source,
            geometry: edits.geometry,
            options: options,
            markup: drawing,
            markupCanvasSize: edits.markup?.canvasSize.cgSize ?? .zero
        )
    }

    private func makeThumbnail(options: PhotoEditorOptions) -> SBJResourceContent? {
#if canImport(PencilKit)
        let drawing: Any? = edits.markup?.pencilKitDrawing
#else
        let drawing: Any? = nil
#endif
        return PhotoEditRenderer.render(
            resource: source,
            geometry: edits.geometry,
            options: options,
            markup: drawing,
            markupCanvasSize: edits.markup?.canvasSize.cgSize ?? .zero,
            maximumPixelDimension: Self.thumbnailMaximumPixelDimension,
            encoding: .thumbnail
        )
    }

    private mutating func rebuildRenderCache(options: PhotoEditorOptions) {
        thumbnail = renderCache.contains(.thumbnail) ? makeThumbnail(options: options) : nil
        rendered = renderCache.contains(.rendered) ? renderedContent(options: options) : nil
    }

    // MARK: - Package persistence

    private func thumbnailForPersistence() -> SBJResourceContent? {
        guard renderCache.contains(.thumbnail) else { return nil }

        if let thumbnail,
           let image = thumbnail.uiImage,
           max(image.size.width, image.size.height) <= Self.thumbnailMaximumPixelDimension {
            return thumbnail
        }
        return makeThumbnail(options: .default)
    }

    private func renderedForPersistence() -> SBJResourceContent? {
        guard renderCache.contains(.rendered),
              let content = rendered ?? renderedContent(options: .default) else {
            return nil
        }
        guard let location else { return content }
        return .init(
            data: location.injectInto(image: content.data, override: true),
            contentType: content.contentType
        )
    }

    private func makeFileWrapper() throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        let sourceExtension = source.contentType.preferredFilenameExtension ?? "data"
        let sourcePath = "source/original.\(sourceExtension)"
        let geometryPath = "edits/geometry.json"
        let colorPath = "edits/color.json"
        let locationPath = location.map { _ in "location.json" }
        let markupPath = edits.markup.map { _ in "edits/markup.data" }
        let persistedThumbnail = thumbnailForPersistence()
        let persistedRendered = renderedForPersistence()
        let thumbnailPath = persistedThumbnail.map {
            "Rendered/thumbnail.\($0.contentType.preferredFilenameExtension ?? "data")"
        }
        let renderedPath = persistedRendered.map {
            "Rendered/full.\($0.contentType.preferredFilenameExtension ?? "data")"
        }

        let manifest = Manifest(
            format: Self.formatIdentifier,
            source: .init(
                path: sourcePath,
                contentType: source.contentType.identifier
            ),
            displayName: edits.displayName,
            description: edits.description,
            geometry: .init(
                path: geometryPath,
                contentType: UTType.json.identifier
            ),
            color: .init(
                path: colorPath,
                contentType: UTType.json.identifier
            ),
            location: location.map { _ in
                .init(
                    path: locationPath!,
                    contentType: UTType.json.identifier
                )
            },
            markup: edits.markup.map {
                .init(
                    path: markupPath!,
                    contentType: $0.contentTypeIdentifier,
                    canvasSize: $0.canvasSize,
                    coordinateSpace: $0.coordinateSpace
                )
            },
            renderCache: renderCache,
            thumbnail: persistedThumbnail.map {
                .init(
                    path: thumbnailPath!,
                    contentType: $0.contentType.identifier
                )
            },
            rendered: persistedRendered.map {
                .init(
                    path: renderedPath!,
                    contentType: $0.contentType.identifier
                )
            }
        )

        var editChildren: [String: FileWrapper] = [
            "geometry.json": .init(regularFileWithContents: try encoder.encode(edits.geometry)),
            "color.json": .init(regularFileWithContents: try encoder.encode(edits.color))
        ]
        if let markup = edits.markup {
            editChildren["markup.data"] = .init(regularFileWithContents: markup.data)
        }

        var root: [String: FileWrapper] = [
            "manifest.json": .init(regularFileWithContents: try encoder.encode(manifest)),
            "source": .init(directoryWithFileWrappers: [
                "original.\(sourceExtension)": .init(regularFileWithContents: source.data)
            ]),
            "edits": .init(directoryWithFileWrappers: editChildren)
        ]
        if let location {
            root["location.json"] = .init(
                regularFileWithContents: try encoder.encode(LocationJSON(location))
            )
        }

        var renderedChildren: [String: FileWrapper] = [:]
        if let persistedThumbnail, let thumbnailPath {
            renderedChildren[URL(fileURLWithPath: thumbnailPath).lastPathComponent] =
                .init(regularFileWithContents: persistedThumbnail.data)
        }
        if let persistedRendered, let renderedPath {
            renderedChildren[URL(fileURLWithPath: renderedPath).lastPathComponent] =
                .init(regularFileWithContents: persistedRendered.data)
        }
        if !renderedChildren.isEmpty {
            root["Rendered"] = .init(directoryWithFileWrappers: renderedChildren)
        }

        return .init(directoryWithFileWrappers: root)
    }
}

public extension SBJResourceContent {
    /// Converts an ordinary encoded image to a non-destructive image-document package.
    /// Existing SBJ image-document packages are returned unchanged. No importing or exporting
    /// UTType declaration is required merely to embed/read/write the package.
    func preservingImageEdits(
		contentType: UTType = SBJImageDocument.contentType,
        renderCache: SBJImageDocument.RenderCache = .thumbnail
    ) -> SBJResourceContent? {
        if contentType.conforms(to: .package),
           (try? SBJImageDocument(resourceContent: self)) != nil {
            return self
        }
        guard self.contentType.conforms(to: .image) else { return nil }
        return SBJImageDocument(source: self, renderCache: renderCache).resourceContent(contentType: contentType)
    }
}

#endif
