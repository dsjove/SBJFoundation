import Foundation

/// Package-backed attachment persistence shared by document-package clients.
/// Attachment keys are filenames and may represent regular files or nested packages.
public enum PackageAttachmentStore {
    public static func isValidFilename(_ filename: String) -> Bool {
        PackageResourceDirectory.isValidPathComponent(filename)
    }

    public static func load(from wrapper: FileWrapper?) -> [String: SBJResourceContent] {
        PackageResourceDirectory.load(
            from: wrapper,
            logicalName: { Self.isValidFilename($0) ? $0 : nil },
            nameIsValid: Self.isValidFilename
        )
    }

    public static func load(from directory: URL) -> [String: SBJResourceContent] {
        PackageResourceDirectory.load(
            from: directory,
            logicalName: { Self.isValidFilename($0) ? $0 : nil },
            nameIsValid: Self.isValidFilename,
            allowsPackages: true
        )
    }

    public static func replaceAll(
        in directory: URL,
        attachments: [String: SBJResourceContent],
        primaryDataDescription: String
    ) -> [PackageDocumentWriteWarning] {
        PackageResourceDirectory.replaceAll(
            in: directory,
            resources: attachments,
            nameIsValid: Self.isValidFilename,
            storageFilename: { name, _ in name },
            logicalName: { $0 },
            resourceDescription: "attachment",
            primaryDataDescription: primaryDataDescription
        )
    }

    public static func replacementWrapper(
        attachments: [String: SBJResourceContent],
        primaryDataDescription: String
    ) -> (wrapper: FileWrapper?, warnings: [PackageDocumentWriteWarning]) {
        PackageResourceDirectory.replacementWrapper(
            resources: attachments,
            nameIsValid: Self.isValidFilename,
            storageFilename: { name, _ in name },
            resourceDescription: "attachment",
            primaryDataDescription: primaryDataDescription
        )
    }
}
