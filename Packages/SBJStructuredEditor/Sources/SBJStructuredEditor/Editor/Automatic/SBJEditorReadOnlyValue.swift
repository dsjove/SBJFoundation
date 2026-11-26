import SBJStructure
import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Read-only presentation never manufactures a writable binding. Compound values
/// use the shared semantic walker, rather than printing their private Swift state.
@MainActor
enum SBJEditorReadOnlyValue {
    static func text(_ value: Any, hints: [SBJPropertyHint] = [], constraints: [SBJPropertyConstraint] = []) -> String {
        // Preserve the original collection policy when an optional wraps a collection.
        if case .optional? = SBJStructuralType.container(of: type(of: value)),
           let container = value as? any SBJStructuralValueContainer {
            guard let child = container.sbjStructuralChildren(itemTitleKey: nil, itemIdentifierKey: nil).first else { return "—" }
            return text(child.value, hints: hints, constraints: constraints)
        }
        if let atomic = value as? any SBJAtomicStructuralValue { return atomic.presentedValue }
        if value is any SBJStructuralSearchAtomic {
            return SBJValueDescription.describe(value) ?? String(describing: value)
        }
        let descendants = SBJStructuralValueWalker.children(
            of: value, identityPath: [], locationPath: [], displayPath: [],
            isPositional: false, ancestorsWritable: false,
            itemTitleKey: SBJStructuralCollectionKeys.title(in: hints),
            itemIdentifierKey: SBJStructuralCollectionKeys.identifier(in: constraints)
        )
        if !descendants.isEmpty {
            let description = descendants.compactMap { occurrence -> String? in
                if let atomic = occurrence.value as? any SBJAtomicStructuralValue {
                    return occurrence.displayPath.joined(separator: " • ") + ": " + atomic.presentedValue
                }
                guard occurrence.value is any SBJStructuralSearchAtomic,
                      let description = SBJValueDescription.describe(occurrence.value) else { return nil }
                return occurrence.displayPath.joined(separator: " • ") + ": " + description
            }.joined(separator: "\n")
            return description.isEmpty ? "—" : description
        }
        if let value = value as? any SBJEnumCaseIdentifiable { return value.sbjCaseName }
        if value is any SBJStructuralValueContainer {
            return "—"
        }
        if value is any SBJStructured { return "—" }
        // Opaque values must explicitly provide a public description; do not reflect fields.
        return (value as? any CustomStringConvertible)?.description ?? "—"
    }
}
#endif
