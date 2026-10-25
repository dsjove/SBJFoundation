import SBJDataDefinition
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Builds the default presentation fields from the canonical structural schema.
/// Presentation configuration is derived from DataDefinition metadata.
@MainActor
enum SBJStructuralFieldProjection {
    static func fields<Root: SBJMutableStructure>(of type: Root.Type) -> [SBJEditorPropertyDescriptor<Root>] {
        let visitor = SBJStructuralFieldCollector<Root>()
        for property in type.sbjMutableProperties {
            property.visitTypedProperty(with: visitor)
        }
        for property in type.sbjPresentationProperties {
            property.visitTypedPresentationProperty(with: visitor)
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
private final class SBJStructuralFieldCollector<Root: SBJMutableStructure>: @preconcurrency SBJTypedStructuralPropertyVisitor, @preconcurrency SBJTypedPresentationPropertyVisitor {
    private(set) var descriptors: [SBJEditorPropertyDescriptor<Root>] = []

    func visit<Value>(_ keyPath: WritableKeyPath<Root, Value>, name: String) {
        descriptors.append(SBJEditorPropertyDescriptor(nonStructuralName: name, keyPath))
    }

    func visit<Value: Codable>(
        _ keyPath: WritableKeyPath<Root, Value>,
        metadata: SBJPropertyMetadata<Root>?
    ) {
        // A presentation exclusion suppresses the field, not the property's
        // structural metadata, validation, or its generated writable key path.
        if metadata?.hints.contains(where: {
            if case .presentationExcluded = $0 { return true }
            return false
        }) == true { return }

        let disclosure: SBJPresentationDisclosureMode = metadata?.hints.compactMap { hint in
            guard case .presentationDisclosure(let mode) = hint else { return nil }
            return mode
        }.first ?? .closed

        // Structural metadata, rather than a display title, is authoritative
        // for the property's name and canonical traversal identity.
        let name = metadata?.displayName ?? String(describing: keyPath)
        descriptors.append(SBJEditorPropertyDescriptor(
            name: name, keyPath, disclosureMode: disclosure
        ))
    }
}
#endif
