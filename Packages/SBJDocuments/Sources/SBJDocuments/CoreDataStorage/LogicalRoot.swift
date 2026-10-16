import SwiftData

/// The result of establishing a logical singleton/root in a SwiftData store.
///
/// CloudKit-backed stores cannot rely on a physical uniqueness constraint to
/// prevent two devices from independently creating the same logical root. This
/// result makes that temporary state explicit while keeping the reconciliation
/// mechanics in SBJFoundation.
public struct LogicalRootResolution<Root: PersistentModel> {
    public let root: Root
    let created: Bool
    public let duplicateCount: Int

    public var reconciledDuplicates: Bool { duplicateCount > 0 }

    init(root: Root, created: Bool, duplicateCount: Int) {
        self.root = root
        self.created = created
        self.duplicateCount = duplicateCount
    }
}

public extension CoreDataStorage {
    /// Establishes one logical root for a model type and reconciles any physical
    /// duplicates already present in the local store.
    ///
    /// `canonicalKey` must be stable for a synchronized record and should impose
    /// a deterministic total order among independently-created roots. The app's
    /// normal persistent UUID is usually appropriate.
    ///
    /// `merge` is intentionally the only domain-specific hook: it must preserve
    /// any meaningful state from `duplicate` in `canonical` before Foundation
    /// deletes the duplicate. The operation should be idempotent because remote
    /// CloudKit changes can cause reconciliation to run repeatedly.
    ///
    /// - Important: This solves eventual duplicate *reconciliation*, not the
    ///   impossible-to-prove question of when an initial CloudKit import is
    ///   "finished." A new root may still be created before an older cloud root
    ///   arrives; a later call will converge them.
    @MainActor
    static func ensureLogicalRoot<Root, Key>(
        _ type: Root.Type = Root.self,
        in context: ModelContext,
        canonicalKey: (Root) -> Key,
        create: () throws -> Root,
        merge: (Root, Root) throws -> Void
    ) throws -> LogicalRootResolution<Root>
    where Root: PersistentModel, Key: Comparable {
        let roots = try context.fetch(FetchDescriptor<Root>())

        guard !roots.isEmpty else {
            let root = try create()
            if root.modelContext == nil {
                context.insert(root)
            } else if root.modelContext !== context {
                preconditionFailure("Logical root was created in a different ModelContext.")
            }
            do {
                try context.saveIfNeeded()
            } catch {
                context.rollback()
                throw error
            }
            return .init(root: root, created: true, duplicateCount: 0)
        }

        // TODO(CoreDataStorage strategy): canonicalKey is required to be unique
        // among independently-created logical roots. If one of the remaining
        // CloudKit apps demonstrates a legitimate key collision, add an explicit
        // tie-break strategy here rather than guessing from ModelContext-local
        // object identity.
        let ordered = roots.sorted { canonicalKey($0) < canonicalKey($1) }
        guard let canonical = ordered.first else {
            preconditionFailure("A non-empty root fetch unexpectedly produced no canonical root.")
        }

        let duplicates = Array(ordered.dropFirst())

        // Persist ownership/content transfers before deleting duplicate roots.
        // This two-phase commit is deliberate: a duplicate root may carry a
        // cascade relationship, and saving the re-parenting first prevents its
        // later deletion from racing with valid child preservation.
        do {
            for duplicate in duplicates {
                try merge(duplicate, canonical)
            }
            try context.saveIfNeeded()
        } catch {
            context.rollback()
            throw error
        }

        // TODO(CoreDataStorage production compatibility): Duplicate deletion is
        // synchronized/destructive. The framework cannot manufacture a useful
        // domain backup, so production clients must snapshot recoverable logical
        // state before calling this API when duplicates may contain user data.
        do {
            for duplicate in duplicates {
                duplicate.deleteNow(save: false)
            }
            try context.saveIfNeeded()
        } catch {
            // The merge phase is already durable. Roll back only the pending
            // deletions; a later reconciliation can safely retry them.
            context.rollback()
            throw error
        }

        return .init(root: canonical, created: false, duplicateCount: duplicates.count)
    }
}
