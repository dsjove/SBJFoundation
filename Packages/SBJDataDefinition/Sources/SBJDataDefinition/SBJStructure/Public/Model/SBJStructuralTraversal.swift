import Foundation

/// A position and property in a structure's stored, writable model.
/// This is independent of editor presentation and binding semantics.
public struct SBJStructuralPropertyLocation<Root: SBJMutableStructure> {
    public let ordinal: Int
    public let property: SBJMutableProperty<Root>

    /// Swift declaration name, stable across display-label changes.
    public var sourceName: String { property.structuralMetadata?.sourceName ?? property.name }

    /// Human-readable label for presentation and generated documentation.
    public var displayName: String { property.structuralMetadata?.displayName ?? property.name }

    /// Compatibility label used by existing consumers of this descriptor.
    public var name: String { displayName }

    /// Structural metadata for documentation, validation, and type inspection.
    public var metadata: SBJPropertyMetadata<Root>? { property.structuralMetadata }

    /// The declared Swift type, without converting it into a display string.
    public var valueType: Any.Type { property.valueType }

    public var locationComponent: String { "field:\(ordinal)" }
    public var identityComponent: String { "property:\(sourceName)" }
}

/// One declared property in an instance-free structural type definition.
///
/// Unlike a writable-property location, this includes immutable (`let`)
/// properties. It is suitable for schema documentation and other tools that
/// describe a type without constructing a value.
public struct SBJStructuralDefinitionProperty<Root: SBJStructured> {
    public let ordinal: Int
    public let metadata: SBJPropertyMetadata<Root>

    public var sourceName: String { metadata.sourceName }
    public var displayName: String { metadata.displayName }
    public var valueType: Any.Type { type(of: metadata.keyPath).valueType }
    public var kind: SBJPropertyKind { metadata.kind }
    public var constraints: [SBJPropertyConstraint] { metadata.constraints }
    public var hints: [SBJPropertyHint] { metadata.hints }
    public var info: SBJPropertyInfo? { metadata.info }

    /// Position is useful for display order; use identity for semantic links.
    public var locationComponent: String { "field:\(ordinal)" }
    public var identityComponent: String { "property:\(sourceName)" }
}

/// Canonical stored-property enumeration. Presentation-only computed fields
/// do not participate in structural traversal.
public enum SBJStructuralTraversal {
    /// Describes *all* coded stored properties in declaration order, including
    /// immutable properties. This is a type-level definition and requires no
    /// instance, no writable property, and no editor-specific conformance.
    public static func definition<Root: SBJStructured>(
        of type: Root.Type
    ) -> [SBJStructuralDefinitionProperty<Root>] {
        type.sbjProperties.enumerated().map { ordinal, metadata in
            SBJStructuralDefinitionProperty(ordinal: ordinal, metadata: metadata)
        }
    }

    /// Visits all structural declarations, even if they cannot be mutated.
    public static func visitDefinition<Root: SBJStructured>(
        of type: Root.Type,
        _ visit: (SBJStructuralDefinitionProperty<Root>) throws -> Void
    ) rethrows {
        for property in definition(of: type) { try visit(property) }
    }

    /// Describes writable stored properties without constructing a model value.
    /// The returned descriptors preserve declaration order and their original
    /// structural metadata. Computed editor-only fields are excluded.
    public static func schema<Root: SBJMutableStructure>(
        of type: Root.Type
    ) -> [SBJStructuralPropertyLocation<Root>] {
        properties(of: type)
    }

    /// Visits the schema in declaration order without requiring an instance.
    public static func visitSchema<Root: SBJMutableStructure>(
        of type: Root.Type,
        _ visit: (SBJStructuralPropertyLocation<Root>) throws -> Void
    ) rethrows {
        for location in schema(of: type) { try visit(location) }
    }

    /// Visits each stored property of a concrete model instance. Value access
    /// is delegated to the same descriptors returned by schema traversal.
    public static func visitValues<Root: SBJMutableStructure>(
        in root: Root,
        _ visit: (SBJStructuralPropertyLocation<Root>, Any) throws -> Void
    ) rethrows {
        for location in schema(of: Root.self) {
            try visit(location, location.property.value(in: root))
        }
    }

    public static func properties<Root: SBJMutableStructure>(
        of type: Root.Type
    ) -> [SBJStructuralPropertyLocation<Root>] {
        type.sbjMutableProperties.enumerated().compactMap { ordinal, property in
            guard property.participatesInStructuralValidation else { return nil }
            return SBJStructuralPropertyLocation(ordinal: ordinal, property: property)
        }
    }
}
