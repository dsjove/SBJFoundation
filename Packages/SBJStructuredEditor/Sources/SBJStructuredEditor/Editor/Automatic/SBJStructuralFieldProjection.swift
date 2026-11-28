import SBJStructure
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Apply editor presentation policy after canonical semantic visibility.
@MainActor
enum SBJStructuralFieldProjection {
    static func fields<Root: SBJMutableStructure>(of type: Root.Type, traversalOptions: SBJTraversalOptions = .editor) -> [SBJEditorPropertyDescriptor<Root>] {
        let visitor = SBJStructuralFieldCollector<Root>()
		for property in type.sbjProperties.filter({ traversalOptions.includes($0) }) {
            property.visitTypedProperty(with: visitor)
        }
        return visitor.descriptors
    }
}

@MainActor
private final class SBJStructuralFieldCollector<Root: SBJMutableStructure>: @preconcurrency SBJTypedPropertyVisitor {
    private(set) var descriptors: [SBJEditorPropertyDescriptor<Root>] = []

    func visit<Value>(_ keyPath: KeyPath<Root, Value>, metadata: SBJPropertyMetadata<Root>) {
        let disclosure: SBJPresentationDisclosureMode = metadata.hints.compactMap { hint in
            guard case .fieldPresentation(let value) = hint else { return nil }
            return value.autoExpand ? .autoOpen : .closed
        }.first ?? .closed
        if metadata.access == .readWrite, let writable = keyPath as? WritableKeyPath<Root, Value> {
            descriptors.append(.init(metadata: metadata, keyPath: writable, disclosureMode: disclosure))
        } else {
            descriptors.append(.init(metadata: metadata, readOnly: keyPath))
        }
    }
}
#endif
