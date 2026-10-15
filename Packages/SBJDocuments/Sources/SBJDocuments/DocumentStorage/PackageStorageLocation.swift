import Foundation

public enum PackageStoragePolicy: Equatable, Sendable {
    case local
    case iCloudPreferred(containerIdentifier: String? = nil)
}

public enum PackageDocumentStorageKind: Equatable, Sendable {
    case iCloud
    case local
    case custom
}

struct PackageStorageResolution: Sendable {
    let kind: PackageDocumentStorageKind
    let directory: URL
    let isUbiquitous: Bool
}

/// Resolves an app-controlled package directory and maps stable document IDs to
/// collision-free package names.
///
/// Storage policy is explicit. A library pins one resolution for its lifetime so
/// an iCloud account/availability change cannot silently switch the user between
/// two document universes while the app is running.
public struct PackageStorageLocation<ID: Sendable>: @unchecked Sendable {
    let directoryName: String
    let packageExtension: String
    let policy: PackageStoragePolicy
    let fileManager: FileManager
    private let storageComponent: @Sendable (ID) -> String

    public init(
        directoryName: String,
        packageExtension: String,
        policy: PackageStoragePolicy = .local,
        fileManager: FileManager = .default,
        storageComponent: @escaping @Sendable (ID) -> String
    ) {
        self.directoryName = directoryName
        self.packageExtension = packageExtension
        self.policy = policy
        self.fileManager = fileManager
        self.storageComponent = storageComponent
    }

    var localDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private var ubiquitousDirectory: URL? {
        guard case .iCloudPreferred(let containerIdentifier) = policy else { return nil }
        return fileManager.url(forUbiquityContainerIdentifier: containerIdentifier)?
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    func resolve(rootOverride: URL? = nil) -> PackageStorageResolution {
        if let rootOverride {
            return .init(kind: .custom, directory: rootOverride, isUbiquitous: false)
        }
        switch policy {
        case .local:
            return .init(kind: .local, directory: localDirectory, isUbiquitous: false)
        case .iCloudPreferred:
            if let ubiquitousDirectory {
                return .init(kind: .iCloud, directory: ubiquitousDirectory, isUbiquitous: true)
            }
            return .init(kind: .local, directory: localDirectory, isUbiquitous: false)
        }
    }

    func storageIDComponent(for id: ID) -> String {
        storageComponent(id)
    }

    public func packageName(for id: ID) -> String {
        storageIDComponent(for: id) + "." + packageExtension
    }

    public func packageURL(for id: ID, root: URL? = nil) -> URL {
        (root ?? resolve().directory).appendingPathComponent(packageName(for: id), isDirectory: true)
    }
}

public extension PackageStorageLocation where ID == String {
    /// Creates a package location for string document IDs using a URL-safe Base64
    /// filesystem representation. User-facing names remain separate from this
    /// stable storage identity.
    init(
        directoryName: String,
        packageExtension: String,
        policy: PackageStoragePolicy = .local,
        fileManager: FileManager = .default
    ) {
        self.init(
            directoryName: directoryName,
            packageExtension: packageExtension,
            policy: policy,
            fileManager: fileManager,
            storageComponent: Self.urlSafeStorageComponent
        )
    }

    private static func urlSafeStorageComponent(_ id: String) -> String {
        let encoded = Data(id.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "id-\(encoded.isEmpty ? "empty" : encoded)"
    }
}
