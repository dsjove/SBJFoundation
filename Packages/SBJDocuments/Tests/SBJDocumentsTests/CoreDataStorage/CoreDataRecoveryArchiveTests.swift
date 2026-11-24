import Foundation
import Testing
@testable import SBJDocuments

@Suite("Core Data recovery snapshots")
struct CoreDataRecoveryArchiveTests {
    private struct Snapshot: Codable, Equatable {
        let version: Int
        let ids: [String]
    }

    @Test("Recovery snapshot round trips without interpreting the client's data")
    func writesAndReadsSnapshot() throws {
        let appIdentifier = "SBJDocumentsTests-\(UUID().uuidString)"
        let original = Snapshot(version: 3, ids: ["first", "second"])
        let url = try CoreDataRecoveryArchive.write(original, appIdentifier: appIdentifier, label: "before-migration")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(try CoreDataRecoveryArchive.read(Snapshot.self, from: url) == original)
        #expect(try CoreDataRecoveryArchive.list(appIdentifier: appIdentifier).map(\.url).contains(url))
    }

    @Test("Recovery snapshots cannot escape their application directory")
    func rejectsUnsafeApplicationIdentifiers() {
        for identifier in ["", ".", "..", "../other", "/tmp/outside", "nested/path", "nested\\path"] {
            #expect(throws: CocoaError.self) {
                _ = try CoreDataRecoveryArchive.write(
                    Snapshot(version: 1, ids: []),
                    appIdentifier: identifier,
                    label: "backup"
                )
            }
        }
    }
}
