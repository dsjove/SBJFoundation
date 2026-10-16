import Foundation
import OSLog
import SwiftData

public enum ModelContextSaveResult {
    case noChanges
    case saved
    case failed(any Error)

    var succeeded: Bool {
        switch self {
        case .noChanges, .saved: true
        case .failed: false
        }
    }
}

private let coreDataStorageLogger = Logger(
    subsystem: "com.softwarebyjove.SBJFoundation",
    category: "CoreDataStorage"
)

public extension ModelContext {
    /// Throwing save primitive for infrastructure code that cannot safely
    /// continue when a local commit fails.
    func saveIfNeeded() throws {
        guard hasChanges else { return }
        try save()
    }

    /// Saves only when the context has pending changes and centralizes routine
    /// persistence diagnostics so ordinary UI callers do not need repetitive
    /// `do/catch` blocks or user-visible alerts for transient failures.
    ///
    /// TODO(CoreDataStorage strategy): The remaining CloudKit apps may reveal
    /// error classes that deserve automatic retry or escalation. Add that policy
    /// here only from concrete evidence; do not make every caller handle it.
    @discardableResult
    func saveChanges(
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) -> ModelContextSaveResult {
        guard hasChanges else { return .noChanges }
        do {
            try save()
            return .saved
        } catch {
            let nsError = error as NSError
            coreDataStorageLogger.error(
                "SwiftData save failed at \(String(describing: file), privacy: .public):\(line, privacy: .public) \(String(describing: function), privacy: .public) — domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) description=\(nsError.localizedDescription, privacy: .public)"
            )
            return .failed(error)
        }
    }

    /// Finds an identifiable persistent model without requiring callers to
    /// duplicate the fetch-and-ID comparison fallback SwiftData currently needs
    /// for generic model IDs.
    func find<T: PersistentModel>(selection id: T.ID?) -> T? where T: Identifiable {
        guard let id else { return nil }
        guard let results = try? fetch(FetchDescriptor<T>()) else { return nil }
        return results.first { $0.id == id }
    }
    // TODO(CoreDataStorage production compatibility): Reassigning a persisted
    // UUID can invalidate manually stored foreign-key UUIDs in released apps.
    // Use this only when callers have audited those references, or supply an
    // app-level repair that updates them together.
    /// Repairs duplicate UUID values in a model type while preserving one
    /// existing value from each collision set. This is intended as an
    /// idempotent data-repair primitive for stores where CloudKit prevents use
    /// of a database uniqueness constraint.
    ///
    /// The callback is diagnostic only; domain repair that depends on an old ID
    /// should remain in the app because a duplicated ID is inherently ambiguous.
    @MainActor
    @discardableResult
    func repairDuplicateUUIDs<T: PersistentModel>(
        _ type: T.Type,
        at keyPath: ReferenceWritableKeyPath<T, UUID>,
        didRepair: ((T, UUID, UUID) -> Void)? = nil
    ) throws -> Int {
        let items = try fetch(FetchDescriptor<T>())
        var seen: Set<UUID> = []
        var repairs = 0

        for item in items {
            let existing = item[keyPath: keyPath]
            if seen.insert(existing).inserted {
                continue
            }

            var replacement = UUID()
            while seen.contains(replacement) {
                replacement = UUID()
            }
            item[keyPath: keyPath] = replacement
            seen.insert(replacement)
            repairs += 1
            didRepair?(item, existing, replacement)
        }

        return repairs
    }

}
