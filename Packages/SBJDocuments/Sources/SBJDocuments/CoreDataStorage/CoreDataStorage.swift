import SwiftData

/// Shared construction and lifecycle helpers for SwiftData/Core Data backed apps.
/// The name reflects the persistence family; app-specific models and migration
/// policy remain in the app.
// TODO(CoreDataStorage production compatibility): Persisted model declarations
// used with a production CloudKit schema must be treated as append-only unless
// compatibility with the deployed schema has been explicitly verified. Do not
// rename/remove persisted properties or relationships merely because client code
// no longer uses them.
public enum CoreDataStorage {
    /// Creates the container but does not make model evolution automatically
    /// safe for a deployed CloudKit schema. Production clients remain responsible
    /// for additive schema compatibility and recoverable data migration.
    public static func makeModelContainer(
        for types: [any PersistentModel.Type],
        version: Schema.Version,
        inMemory: Bool = false,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .automatic
    ) throws -> ModelContainer {
        let schema = Schema(types, version: version)
        let configuration = inMemory
            ? ModelConfiguration(isStoredInMemoryOnly: true)
            : ModelConfiguration(cloudKitDatabase: cloudKitDatabase)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
