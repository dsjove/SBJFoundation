import Foundation

/// File-based recovery snapshots for production persistence migrations.
///
/// CloudKit synchronization is not a backup. A destructive repair can sync to
/// every device, so apps that mutate an existing production store should take a
/// logical, Codable snapshot before the mutation. The app owns the snapshot
/// schema; CoreDataStorage owns safe local storage, retention, and decoding.
public enum CoreDataRecoveryArchive {
    public struct Entry: Identifiable, Sendable {
        public let url: URL
        public let date: Date

        public var id: URL { url }
        public var name: String { url.lastPathComponent }
    }

    private static func directory(appIdentifier: String) throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base
            .appendingPathComponent("SBJCoreDataRecovery", isDirectory: true)
            .appendingPathComponent(appIdentifier, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Writes a complete logical snapshot atomically and prunes older snapshots.
    /// The label should identify the migration/reconciliation boundary, not user
    /// content. `retaining` deliberately defaults small because snapshots may
    /// contain externally-stored photos or attachments.
    @discardableResult
    public static func write<Snapshot: Encodable>(
        _ snapshot: Snapshot,
        appIdentifier: String,
        label: String,
        retaining: Int = 5,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> URL {
        let directory = try directory(appIdentifier: appIdentifier)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let stamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let safeLabel = label
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent("\(stamp)-\(safeLabel).json")

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: [.atomic])

        if retaining >= 0 {
            let entries = try list(appIdentifier: appIdentifier)
            for old in entries.dropFirst(max(0, retaining)) {
                try? FileManager.default.removeItem(at: old.url)
            }
        }
        return url
    }

    public static func list(appIdentifier: String) throws -> [Entry] {
        let directory = try directory(appIdentifier: appIdentifier)
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        return try urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .map { url in
                let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
                return Entry(url: url, date: values.contentModificationDate ?? .distantPast)
            }
            .sorted { $0.date > $1.date }
    }

    public static func read<Snapshot: Decodable>(
        _ type: Snapshot.Type,
        from url: URL,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> Snapshot {
        try decoder.decode(type, from: Data(contentsOf: url))
    }
}

// TODO(CoreDataStorage production compatibility): When the remaining production
// apps adopt recovery snapshots, compare their needs before adding encryption,
// iCloud/file-export integration, or a framework-level restore UI. The current
// primitive intentionally stores only app-supplied logical snapshots locally.
