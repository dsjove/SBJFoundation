import Foundation

/// Model-only lookup for declaration identity and ordinal position.
/// Editors and semantic consumers share these values without sharing UI state.
public struct SBJStructuralLocation: Equatable, Sendable {
    public let identity: String
    public let location: String

    public init(identity: String, location: String) {
        self.identity = identity
        self.location = location
    }
}

public enum SBJStructuralLocationLookup {
    /// Returns the declared location of a writable property, if present.
    public static func resolve<Root: SBJMutableStructure>(
        sourceName: String, in type: Root.Type, options: SBJTraversalOptions = .editor
    ) -> SBJStructuralLocation? {
        SBJStructuralTraversal.schema(of: type, options: options)
            .first(where: { $0.sourceName == sourceName })
            .map { SBJStructuralLocation(identity: $0.identityComponent, location: $0.locationComponent) }
    }

    /// Resolve a set of property source names using one schema traversal.
    public static func locations<Root: SBJMutableStructure>(
        of type: Root.Type, options: SBJTraversalOptions = .editor
    ) -> [String: SBJStructuralLocation] {
        Dictionary(uniqueKeysWithValues: SBJStructuralTraversal.schema(of: type, options: options).map {
            ($0.sourceName, SBJStructuralLocation(identity: $0.identityComponent, location: $0.locationComponent))
        })
    }

    /// Locations for every discoverable property, including immutable ones.
    /// Read-only consumers should use this rather than the writable schema.
    public static func definitionLocations<Root: SBJStructured>(
        of type: Root.Type, options: SBJTraversalOptions = .definition
    ) -> [String: SBJStructuralLocation] {
        Dictionary(uniqueKeysWithValues: SBJStructuralTraversal.definition(of: type, options: options).map {
            ($0.sourceName, SBJStructuralLocation(identity: $0.identityComponent, location: $0.locationComponent))
        })
    }

    /// Resolve an immutable or mutable declared property by source name.
    public static func definitionLocation<Root: SBJStructured>(
        sourceName: String, in type: Root.Type, options: SBJTraversalOptions = .definition
    ) -> SBJStructuralLocation? {
        SBJStructuralTraversal.definition(of: type, options: options)
            .first(where: { $0.sourceName == sourceName })
            .map { SBJStructuralLocation(identity: $0.identityComponent, location: $0.locationComponent) }
    }

}
