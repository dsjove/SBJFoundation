import SwiftData

public extension PersistentModel {
    /// Inserts a model into the supplied context, populates it, then saves using
    /// the shared save policy. Re-inserting into the same context is harmless;
    /// attempting to move a live model between contexts is rejected.
    @discardableResult
    func insertNow(
        _ context: ModelContext?,
        save: Bool = true,
        populate: (Self) -> Void = { _ in }
    ) -> Self {
        guard let context else {
            populate(self)
            return self
        }

        if let existing = modelContext {
            guard existing === context else {
                assertionFailure("Attempted to insert a PersistentModel into a different ModelContext.")
                return self
            }
        } else {
            context.insert(self)
        }

        populate(self)
        if save {
            context.saveChanges()
        }
        return self
    }

    // TODO(CoreDataStorage production compatibility): Deletion in a CloudKit
    // store is destructive across synchronized devices. Production migrations
    // should create a logical recovery snapshot before invoking deletion as part
    // of reconciliation or data repair.
    /// Deterministic deletion entry point.
    ///
    /// Migrated `Teardownable` models opt into preparation-only teardown with
    /// `tearDownDeletesSelf == false`; Foundation invokes that cleanup before
    /// deletion. Legacy models retain their historical self-deleting teardown
    /// semantics until their apps are migrated.
    func deleteNow(save: Bool = true) {
        guard !isDeleted else { return }

        if let teardown = self as? any Teardownable,
           !teardown.tearDownDeletesSelf {
            teardown.tearDown()
        }

        guard let context = modelContext else { return }
        context.delete(self)
        if save {
            context.saveChanges()
        }
    }

    @discardableResult
    internal func saveNow() -> ModelContextSaveResult {
        guard let context = modelContext else { return .noChanges }
        return context.saveChanges()
    }
}
