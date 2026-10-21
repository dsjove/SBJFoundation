import Foundation
#if canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

/// A displayable reference to data stored either in an asset-catalog data set or as an ordinary bundle resource.
public struct SBJBundledContentReference: Hashable {
    public enum Storage: Hashable {
        case dataAsset(name: String)
        case bundleResource(name: String, extension: String?, subdirectory: String?)
    }

    /// Human-readable name for UI that presents this asset.
    public let displayName: String
    public let bundle: Bundle
    public let storage: Storage
    public let contentTypeOverride: UTType?

    public init(
        displayName: String? = nil,
        dataAsset name: String,
        bundle: Bundle = .main,
        contentType: UTType? = nil
    ) {
        self.displayName = displayName ?? name
        self.bundle = bundle
        self.storage = .dataAsset(name: name)
        self.contentTypeOverride = contentType
    }

    /// Creates a bundle-resource reference. When `resourceName` is omitted, the display name is
    /// converted to a filename with `String.sanitizedFilename(removeInnerWhiteSpace: true)`. When
    /// `resourceExtension` is omitted, it is inferred from `contentType` when possible.
    public init(
        displayName: String,
        resourceName: String? = nil,
        resourceExtension: String? = nil,
        subdirectory: String? = nil,
        bundle: Bundle = .main,
        contentType: UTType? = nil
    ) {
        let resolvedName = resourceName ?? displayName.sanitizedFilename(removeInnerWhiteSpace: true)
        let resolvedExtension = resourceExtension ?? contentType?.preferredFilenameExtension
        self.displayName = displayName
        self.bundle = bundle
        self.storage = .bundleResource(
            name: resolvedName,
            extension: resolvedExtension,
            subdirectory: subdirectory
        )
        self.contentTypeOverride = contentType ?? resolvedExtension.flatMap { UTType(filenameExtension: $0) }
    }

    /// Stable identity independent of the resolved resource URL.
    public var fullName: String {
        switch storage {
        case .dataAsset(let name):
            return name
        case .bundleResource(let name, let ext, let subdirectory):
            let file = ext.map { "\(name).\($0)" } ?? name
            guard let subdirectory, !subdirectory.isEmpty else { return file }
            return subdirectory + "/" + file
        }
    }

    #if canImport(UIKit)
    private var dataAsset: NSDataAsset? {
        guard case .dataAsset(let name) = storage else { return nil }
        return NSDataAsset(name: name, bundle: bundle)
    }
    #endif

    private var dataAssetData: Data? {
        #if canImport(UIKit)
        dataAsset?.data
        #else
        nil
        #endif
    }

    private var dataAssetTypeIdentifier: String? {
        #if canImport(UIKit)
        dataAsset?.typeIdentifier
        #else
        nil
        #endif
    }

    private var dataAssetExists: Bool {
        #if canImport(UIKit)
        dataAsset != nil
        #else
        false
        #endif
    }

    private var resourceURL: URL? {
        guard case let .bundleResource(name, ext, subdirectory) = storage else { return nil }
        return bundle.sbjResourceURL(
            name: name,
            extension: ext,
            subdirectory: subdirectory
        )
    }

    public func dataValue() -> Data? {
        switch storage {
        case .dataAsset:
            return dataAssetData
        case .bundleResource:
            guard let resourceURL else { return nil }
            return try? Data(contentsOf: resourceURL)
        }
    }

    public func stringValue() -> String? {
        guard let data = dataValue() else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public var contentType: UTType? {
        switch storage {
        case .dataAsset:
            return Self.resolvedContentType(
                override: contentTypeOverride,
                assetTypeIdentifier: dataAssetTypeIdentifier
            )
        case .bundleResource(_, let ext, _):
            if let contentTypeOverride { return contentTypeOverride }
            return ext.flatMap { UTType(filenameExtension: $0) }
        }
    }

    public var exists: Bool {
        switch storage {
        case .dataAsset:
            return dataAssetExists
        case .bundleResource:
            return resourceURL != nil
        }
    }

    public static func resolvedContentType(
        override: UTType?,
        assetTypeIdentifier: String?
    ) -> UTType? {
        if let override { return override }
        guard let assetTypeIdentifier, !assetTypeIdentifier.isEmpty else { return nil }
        return UTType(assetTypeIdentifier)
    }
}
