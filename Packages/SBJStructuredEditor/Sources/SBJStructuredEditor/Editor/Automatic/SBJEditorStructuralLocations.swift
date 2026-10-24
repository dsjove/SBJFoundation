import SBJDataDefinition
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Resolves editor field locations against one snapshot of the structural schema.
/// Stored properties preserve their source identity; computed presentation-only
/// fields intentionally remain outside the structural model.
@MainActor
enum SBJEditorStructuralLocations {
    static func resolve<Root: SBJMutableStructure>(
        _ fields: [SBJEditorPropertyDescriptor<Root>], of type: Root.Type,
        startingAt: Int = 0
    ) -> [(identity: String, location: String)] {
        let schema = Dictionary(
            uniqueKeysWithValues: SBJStructuralTraversal.schema(of: type).map {
                ($0.sourceName, (identity: $0.identityComponent, location: $0.locationComponent))
            }
        )
        return fields.enumerated().map { ordinal, field in
            if let source = field.editableField.structuralMetadata?.sourceName,
               let structural = schema[source] {
                return structural
            }
            return (identity: "editor-property:\(field.name)", location: "editor-field:\(startingAt + ordinal)")
        }
    }
}
#endif
