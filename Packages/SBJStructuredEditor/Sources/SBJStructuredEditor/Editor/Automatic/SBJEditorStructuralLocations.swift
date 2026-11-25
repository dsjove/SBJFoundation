import SBJStructure
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Resolves editor field locations against one snapshot of the structural schema.
/// Every published property preserves its declaration identity, regardless of writability.
@MainActor
enum SBJEditorStructuralLocations {
    static func resolve<Root: SBJMutableStructure>(
        _ fields: [SBJEditorPropertyDescriptor<Root>], of type: Root.Type,
        startingAt: Int = 0
    ) -> [(identity: String, location: String)] {
        let schema = SBJStructuralLocationLookup.definitionLocations(of: type)
        return fields.enumerated().map { ordinal, field in
            if let structural = schema[field.metadata.sourceName] {
                return (identity: structural.identity, location: structural.location)
            }
            return (identity: "editor-property:\(field.name)", location: "editor-field:\(startingAt + ordinal)")
        }
    }
}
#endif
