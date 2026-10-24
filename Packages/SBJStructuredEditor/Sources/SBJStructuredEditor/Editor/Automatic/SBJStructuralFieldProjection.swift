import SBJDataDefinition
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Builds the default presentation fields from the canonical structural schema.
/// A caller may supply explicit editor fields instead; those annotations are not
/// part of the underlying structural definition.
@MainActor
enum SBJStructuralFieldProjection {
    static func fields<Root: SBJMutableStructure>(of type: Root.Type) -> [SBJEditorPropertyDescriptor<Root>] {
        let visitor = SBJStructuralFieldCollector<Root>()
        for property in type.sbjMutableProperties {
            property.visitTypedProperty(with: visitor)
        }
        return visitor.descriptors
    }
}

/// The typed property witness constructs each field while `Value` is still
/// known to the compiler. No name-based dispatch or force-casting is involved.
// This collector is only created and visited by the main-actor editor projection.
// The general-purpose DataDefinition visitor does not impose actor isolation
// on other consumers (for example, a documentation generator).
@MainActor
private final class SBJStructuralFieldCollector<Root: SBJMutableStructure>: @preconcurrency SBJTypedStructuralPropertyVisitor {
    private(set) var descriptors: [SBJEditorPropertyDescriptor<Root>] = []

    func visit<Value: Codable>(
        _ keyPath: WritableKeyPath<Root, Value>,
        metadata: SBJPropertyMetadata<Root>?
    ) {
        // Structural metadata, not an editor label, supplies the public name.
        // Explicit @SBJEditable descriptors may independently customize it.
        let name = metadata?.sourceName ?? String(describing: keyPath)
        descriptors.append(SBJEditorPropertyDescriptor(name: name, keyPath))
    }
}
#endif
