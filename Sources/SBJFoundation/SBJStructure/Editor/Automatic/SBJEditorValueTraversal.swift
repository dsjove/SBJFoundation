#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Describes compound descendants without constructing any SwiftUI views.
/// The flat editor projection consumes these descriptors without nested views.
@MainActor
protocol SBJEditorTraversableValue {
    static func sbjTraversalChildren(
        of value: Any,
        context: SBJEditTraversalContext,
        itemTitleKey: String?,
        itemIdentifierKey: String?
    ) -> [SBJEditorTraversalNode]
}

@MainActor
protocol SBJEditorBoundTraversableValue {
    static func sbjBoundTraversalChildren(
        binding: SBJAnyBinding,
        originalValue: Any?,
        context: SBJEditTraversalContext,
        registry: SBJEditorRegistry,
        itemTitleKey: String?,
        itemIdentifierKey: String?
    ) -> [SBJEditorTraversalNode]
}

@MainActor
enum SBJEditorValueTraversal {
    static func children<Value>(
        of value: Value,
        context: SBJEditTraversalContext,
        itemTitleKey: String? = nil,
        itemIdentifierKey: String? = nil
    ) -> [SBJEditorTraversalNode] {
        if let associated = Value.self as? any SBJEditableAssociatedEnum.Type {
            return associated._sbjAssociatedTraversalNodes(value: value, context: context)
        }
        if let structured = Value.self as? any SBJSwiftUIEditable.Type {
            return structured._sbjTraversalNodes(value: value, context: context)
        }
        if let compound = Value.self as? any SBJEditorTraversableValue.Type {
            return compound.sbjTraversalChildren(of: value, context: context, itemTitleKey: itemTitleKey, itemIdentifierKey: itemIdentifierKey)
        }
        return []
    }

    static func boundChildren<Value>(
        of binding: Binding<Value>,
        originalValue: Value? = nil,
        context: SBJEditTraversalContext,
        registry: SBJEditorRegistry,
        itemTitleKey: String? = nil,
        itemIdentifierKey: String? = nil
    ) -> [SBJEditorTraversalNode] {
        if let associated = Value.self as? any SBJEditableAssociatedEnum.Type {
            return associated._sbjBoundAssociatedTraversalNodes(
                binding: SBJAnyBinding(binding), originalValue: originalValue, registry: registry, context: context
            )
        }
        if let structured = Value.self as? any SBJSwiftUIEditable.Type {
            return structured._sbjBoundTraversalNodes(
                binding: SBJAnyBinding(binding), originalValue: originalValue, registry: registry, context: context
            )
        }
        if let compound = Value.self as? any SBJEditorBoundTraversableValue.Type {
            return compound.sbjBoundTraversalChildren(
                binding: SBJAnyBinding(binding), originalValue: originalValue, context: context,
                registry: registry, itemTitleKey: itemTitleKey,
                itemIdentifierKey: itemIdentifierKey
            )
        }
        return []
    }

    static func boundNode<Value>(
        named name: String, binding: Binding<Value>, originalValue: Value? = nil,
        context: SBJEditTraversalContext, registry: SBJEditorRegistry
    ) -> SBJEditorTraversalNode {
        SBJEditorTraversalNode(
            context: context, name: name,
            isDisclosure: Value.self is any SBJSwiftUIEditable.Type
                || Value.self is any SBJEditorTraversableValue.Type
                || Value.self is any SBJEditableAssociatedEnum.Type,
            render: { renderedContext in
                SBJValueEditor.makeView(
                    label: name, value: binding, registry: registry,
                    context: renderedContext,
                    headerOnly: true
                )
            },
            // Reuse the same content check as the recursive collection editors.
            // Changed-only comparison still needs the original collection value;
            // keeping entries included avoids incorrectly hiding edited rows.
            isIncluded: { criteria in
                criteria.includes(
                    isChanged: originalValue.map { !SBJStructuralCompare.equals(binding.wrappedValue, $0) } ?? true,
                    containsEmptyContent: SBJContentCheck.containsEmptyContent(
                        binding.wrappedValue,
                        treatingAsLeaf: { registry.hasCustomEditor($0) }
                    ),
                    matchesSearch: { query in
                        sbjPredicated(label: name, value: binding.wrappedValue, search: query)
                    }
                )
            },
            children: { projectedContext in
                boundChildren(of: binding, originalValue: originalValue, context: projectedContext, registry: registry)
            }
        )
    }

    static func node<Value>(
        named name: String,
        value: Value,
        context: SBJEditTraversalContext
    ) -> SBJEditorTraversalNode {
        SBJEditorTraversalNode(
            context: context,
            name: name,
            isDisclosure: Value.self is any SBJSwiftUIEditable.Type
                || Value.self is any SBJEditorTraversableValue.Type
                || Value.self is any SBJEditableAssociatedEnum.Type,
            children: { projectedContext in
                children(of: value, context: projectedContext)
            }
        )
    }
}

extension Optional: SBJEditorTraversableValue {
    static func sbjTraversalChildren(
        of value: Any,
        context: SBJEditTraversalContext,
        itemTitleKey: String?,
        itemIdentifierKey: String?
    ) -> [SBJEditorTraversalNode] {
        guard let optional = value as? Wrapped?, let wrapped = optional else { return [] }
        // An optional's wrapped value is rendered at the optional's own depth
        // in the recursive editor. Its descendants retain their normal paths.
        return SBJEditorValueTraversal.children(of: wrapped, context: context, itemTitleKey: itemTitleKey, itemIdentifierKey: itemIdentifierKey)
    }
}

extension Array: SBJEditorTraversableValue {
    static func sbjTraversalChildren(
        of value: Any,
        context: SBJEditTraversalContext,
        itemTitleKey: String?,
        itemIdentifierKey: String?
    ) -> [SBJEditorTraversalNode] {
        guard let elements = value as? [Element] else { return [] }
        return elements.enumerated().map { index, element in
            let configuredID = SBJCollectionItemIdentification.stableIdentifier(
                for: element, itemIdentifierKey: itemIdentifierKey
            )
            let stable: String
            if let configuredID, let itemIdentifierKey,
               SBJCollectionItemIdentification.uniqueIndex(
                   in: elements, identifier: configuredID, itemIdentifierKey: itemIdentifierKey
               ) != nil {
                stable = configuredID
            } else {
                // Missing/duplicate identifiers cannot safely represent logical identity.
                stable = "slot:\(index)"
            }
            let title = SBJCollectionItemIdentification.arrayTitle(
                for: element, index: index, itemTitleKey: itemTitleKey
            )
            let childContext = SBJEditTraversalContext(
                treeLevel: context.treeLevel + 1,
                itemIdentifier: context.itemIdentifier.appending("item:\(stable)"),
                indexPath: context.indexPath.appending("index:\(index)"),
                navigationPath: context.navigationPath + [title],
                branch: context.branch.child
            )
            return SBJEditorValueTraversal.node(named: title, value: element, context: childContext)
        }
    }
}

extension Set: SBJEditorTraversableValue {
    static func sbjTraversalChildren(
        of value: Any,
        context: SBJEditTraversalContext,
        itemTitleKey: String?,
        itemIdentifierKey: String?
    ) -> [SBJEditorTraversalNode] {
        guard let values = value as? Set<Element> else { return [] }
        return SBJCollectionOrdering.sorted(values).map { element in
            let stable = "\(String(reflecting: type(of: element))):\(String(reflecting: element))"
            let title = SBJCollectionItemIdentification.title(for: element, itemTitleKey: itemTitleKey)
            let childContext = SBJEditTraversalContext(
                treeLevel: context.treeLevel + 1,
                itemIdentifier: context.itemIdentifier.appending("item:\(stable)"),
                indexPath: context.indexPath.appending("item:\(stable)"),
                navigationPath: context.navigationPath + [title],
                branch: context.branch.child
            )
            return SBJEditorValueTraversal.node(named: title, value: element, context: childContext)
        }
    }
}

extension Dictionary: SBJEditorTraversableValue {
    static func sbjTraversalChildren(
        of value: Any,
        context: SBJEditTraversalContext,
        itemTitleKey: String?,
        itemIdentifierKey: String?
    ) -> [SBJEditorTraversalNode] {
        guard let values = value as? [Key: Value] else { return [] }
        return SBJCollectionOrdering.sortedEntries(values).map { key, element in
            let keyText = String(reflecting: key)
            let title = String(describing: key)
            let childContext = SBJEditTraversalContext(
                treeLevel: context.treeLevel + 1,
                itemIdentifier: context.itemIdentifier.appending("key:\(keyText)"),
                indexPath: context.indexPath.appending("key:\(keyText)"),
                navigationPath: context.navigationPath + [title],
                branch: context.branch.child
            )
            return SBJEditorValueTraversal.node(named: title, value: element, context: childContext)
        }
    }
}

// The closures below retain the parent binding, never a copy of the model.
// A lazy row therefore resolves the current value when instantiated.
extension Optional: SBJEditorBoundTraversableValue {
    static func sbjBoundTraversalChildren(
        binding: SBJAnyBinding, originalValue: Any?, context: SBJEditTraversalContext,
        registry: SBJEditorRegistry, itemTitleKey: String?, itemIdentifierKey: String?
    ) -> [SBJEditorTraversalNode] {
        let parent = binding.binding(as: Optional<Wrapped>.self)
        guard let capturedWrappedValue = parent.wrappedValue else { return [] }
        let child = Binding<Wrapped>(
            // A deferred row may outlive an optional being cleared. Return
            // its last-known value without force-unwrapping an absent model.
            get: { parent.wrappedValue ?? capturedWrappedValue },
            set: { parent.wrappedValue = $0 }
        )
        return SBJEditorValueTraversal.boundChildren(
            of: child, originalValue: (originalValue as? Wrapped?) ?? nil, context: context, registry: registry,
            itemTitleKey: itemTitleKey, itemIdentifierKey: itemIdentifierKey
        )
    }
}

extension Array: SBJEditorBoundTraversableValue {
    static func sbjBoundTraversalChildren(
        binding: SBJAnyBinding, originalValue: Any?, context: SBJEditTraversalContext,
        registry: SBJEditorRegistry, itemTitleKey: String?, itemIdentifierKey: String?
    ) -> [SBJEditorTraversalNode] {
        let parent = binding.binding(as: [Element].self)
        let snapshot = parent.wrappedValue
        return snapshot.enumerated().map { index, element in
            let configuredID = SBJCollectionItemIdentification.stableIdentifier(
                for: element, itemIdentifierKey: itemIdentifierKey
            )
            let stable: String
            if let configuredID, let itemIdentifierKey,
               SBJCollectionItemIdentification.uniqueIndex(
                   in: snapshot, identifier: configuredID, itemIdentifierKey: itemIdentifierKey
               ) != nil {
                stable = configuredID
            } else {
                // Missing/duplicate identifiers cannot safely represent logical identity.
                stable = "slot:\(index)"
            }
            let title = SBJCollectionItemIdentification.arrayTitle(
                for: element, index: index, itemTitleKey: itemTitleKey
            )
            let childContext = SBJEditTraversalContext(
                treeLevel: context.treeLevel + 1,
                itemIdentifier: context.itemIdentifier.appending("item:\(stable)"),
                indexPath: context.indexPath.appending("index:\(index)"),
                navigationPath: context.navigationPath + [title],
                branch: context.branch.child
            )
            // A configured item identifier denotes logical identity, not the
            // position occupied when this descriptor was created. Resolve its
            // current index on each access so moves and insertions cannot
            // redirect edits to an unrelated item.
            let resolvedIndex: () -> Int? = {
                let values = parent.wrappedValue
                if let itemIdentifierKey {
                    guard let identifier = SBJCollectionItemIdentification.stableIdentifier(
                        for: element, itemIdentifierKey: itemIdentifierKey
                    ) else { return nil }
                    return SBJCollectionItemIdentification.uniqueIndex(
                        in: values, identifier: identifier, itemIdentifierKey: itemIdentifierKey
                    )
                }
                return values.indices.contains(index) ? index : nil
            }
            let elementBinding = Binding<Element>(
                get: {
                    guard let currentIndex = resolvedIndex() else { return element }
                    return parent.wrappedValue[currentIndex]
                },
                set: { newValue in
                    guard let currentIndex = resolvedIndex() else { return }
                    var values = parent.wrappedValue
                    guard values.indices.contains(currentIndex) else { return }
                    values[currentIndex] = newValue
                    parent.wrappedValue = values
                }
            )
            let originalElements = originalValue as? [Element]
            let originalElement: Element? = {
                guard let originalElements else { return nil }
                if let itemIdentifierKey,
                   let identifier = SBJCollectionItemIdentification.stableIdentifier(
                       for: element, itemIdentifierKey: itemIdentifierKey
                   ) {
                    guard let originalIndex = SBJCollectionItemIdentification.uniqueIndex(
                        in: originalElements, identifier: identifier, itemIdentifierKey: itemIdentifierKey
                    ) else { return nil }
                    return originalElements[originalIndex]
                }
                return originalElements.indices.contains(index) ? originalElements[index] : nil
            }()
            return SBJEditorValueTraversal.boundNode(
                named: title, binding: elementBinding, originalValue: originalElement,
                context: childContext, registry: registry
            )
        }
    }
}

// Set members are edited as drafts and committed atomically. Exposing a direct
// element Binding would silently bypass collision detection and Apply semantics.
// Keep each set entry as one independently renderable row until a future flat
// renderer can explicitly model its draft editor and nested contents.
extension Set: SBJEditorBoundTraversableValue where Element: Codable {
    static func sbjBoundTraversalChildren(
        binding: SBJAnyBinding, originalValue: Any?, context: SBJEditTraversalContext,
        registry: SBJEditorRegistry, itemTitleKey: String?, itemIdentifierKey: String?
    ) -> [SBJEditorTraversalNode] {
        let parent = binding.binding(as: Set<Element>.self)
        return SBJCollectionOrdering.sorted(parent.wrappedValue).map { element in
            let stable = "\(String(reflecting: type(of: element))):\(String(reflecting: element))"
            let title = SBJCollectionItemIdentification.title(for: element, itemTitleKey: itemTitleKey)
            let childContext = SBJEditTraversalContext(
                treeLevel: context.treeLevel + 1,
                itemIdentifier: context.itemIdentifier.appending("item:\(stable)"),
                indexPath: context.indexPath.appending("item:\(stable)"),
                navigationPath: context.navigationPath + [title],
                branch: context.branch.child
            )
            return SBJEditorTraversalNode(
                context: childContext, name: title,
                render: { renderedContext in
                    AnyView(SBJSetEntryEditor(
                        element: element,
                        originalElement: (originalValue as? Set<Element>)?.contains(element) == true ? element : nil,
                        title: title,
                        registry: registry,
                        context: renderedContext,
                        replace: { old, replacement in
                            var values = parent.wrappedValue
                            let replaced = values.sbjReplace(old, with: replacement)
                            if replaced { parent.wrappedValue = values }
                            return replaced
                        },
                        remove: {
                            var values = parent.wrappedValue
                            values.remove(element)
                            parent.wrappedValue = values
                        }
                    ))
                },
                    isIncluded: { criteria in
                    criteria.includes(
                        isChanged: (originalValue as? Set<Element>)?.contains(element) != true,
                        containsEmptyContent: SBJContentCheck.containsEmptyContent(
                            element,
                            treatingAsLeaf: { registry.hasCustomEditor($0) }
                        ),
                        matchesSearch: { query in
                            sbjPredicated(label: title, value: element, search: query)
                        }
                    )
                }
            )
        }
    }
}

extension Dictionary: SBJEditorBoundTraversableValue {
    static func sbjBoundTraversalChildren(
        binding: SBJAnyBinding, originalValue: Any?, context: SBJEditTraversalContext,
        registry: SBJEditorRegistry, itemTitleKey: String?, itemIdentifierKey: String?
    ) -> [SBJEditorTraversalNode] {
        let parent = binding.binding(as: [Key: Value].self)
        return SBJCollectionOrdering.sortedEntries(parent.wrappedValue).map { key, entryValue in
            let keyText = String(reflecting: key)
            let title = String(describing: key)
            let childContext = SBJEditTraversalContext(
                treeLevel: context.treeLevel + 1,
                itemIdentifier: context.itemIdentifier.appending("key:\(keyText)"),
                indexPath: context.indexPath.appending("key:\(keyText)"),
                navigationPath: context.navigationPath + [title],
                branch: context.branch.child
            )
            let valueBinding = Binding<Value>(
                get: { parent.wrappedValue[key] ?? entryValue },
                set: { newValue in
                    var values = parent.wrappedValue
                    guard values.keys.contains(key) else { return }
                    values[key] = newValue
                    parent.wrappedValue = values
                }
            )
            return SBJEditorValueTraversal.boundNode(
                named: title, binding: valueBinding,
                originalValue: (originalValue as? [Key: Value])?[key],
                context: childContext, registry: registry
            )
        }
    }
}
#endif
