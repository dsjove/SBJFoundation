/// Stable logical identity for one item in an editor snapshot.
///
/// Like a collection-view item identifier, this answers *which logical item is
/// this?* It is intentionally distinct from ``SBJEditorIndexPath``, which says
/// where the item is currently presented.
public struct SBJEditorItemIdentifier: Hashable, Sendable, CustomStringConvertible {
    public let components: [String]

    public init(components: [String] = []) {
        self.components = components
    }

    public func appending(_ component: String) -> Self {
        Self(components: components + [component])
    }

    public var description: String { components.joined(separator: "/") }

    public static let root = Self(components: ["root"])
}

/// Current presentation location of an item in the editor hierarchy.
///
/// This is the editor equivalent of a collection-view index path. Moving an
/// item may change its index path without changing its item identifier.
public struct SBJEditorIndexPath: Hashable, Sendable, CustomStringConvertible {
    public let components: [String]

    public init(components: [String] = []) {
        self.components = components
    }

    public func appending(_ component: String) -> Self {
        Self(components: components + [component])
    }

    public var description: String { components.joined(separator: "/") }

    public static let root = Self()
}

/// One item in the currently presented editor snapshot.
///
/// `itemIdentifier` supplies SwiftUI identity, `indexPath` records current
/// location, and `content` is the current item configuration/value.
public struct SBJEditorSnapshotItem<Content>: Identifiable {
    public let itemIdentifier: SBJEditorItemIdentifier
    public let indexPath: SBJEditorIndexPath
    public let content: Content

    public var id: SBJEditorItemIdentifier { itemIdentifier }

    public init(
        itemIdentifier: SBJEditorItemIdentifier,
        indexPath: SBJEditorIndexPath,
        content: Content
    ) {
        self.itemIdentifier = itemIdentifier
        self.indexPath = indexPath
        self.content = content
    }
}

/// UI-independent position within a recursively edited value tree.
///
/// In addition to indentation depth, traversal carries collection-view-style
/// item identity and index-path information. Search/filtering may change the
/// visible snapshot without changing logical item identifiers.
public struct SBJEditTraversalContext: Hashable, Sendable {
    public let treeLevel: Int
    public let itemIdentifier: SBJEditorItemIdentifier
    public let indexPath: SBJEditorIndexPath
    public let navigationPath: [String]

    public init(
        treeLevel: Int = 0,
        itemIdentifier: SBJEditorItemIdentifier = .root,
        indexPath: SBJEditorIndexPath = .root,
        navigationPath: [String] = []
    ) {
        precondition(treeLevel >= 0, "treeLevel cannot be negative")
        self.treeLevel = treeLevel
        self.itemIdentifier = itemIdentifier
        self.indexPath = indexPath
        self.navigationPath = navigationPath
    }

    public static let root = SBJEditTraversalContext()

    /// Identifies a property at the current visual level.
    public func property(_ name: String) -> SBJEditTraversalContext {
        SBJEditTraversalContext(
            treeLevel: treeLevel,
            itemIdentifier: itemIdentifier.appending("property:\(name)"),
            indexPath: indexPath.appending("property:\(name)"),
            navigationPath: navigationPath + [name]
        )
    }

    /// Descends to a child property.
    public func descended(property name: String) -> SBJEditTraversalContext {
        property(name).descended()
    }

    /// Descends to a collection item. `stableIdentifier` identifies the logical
    /// item while `index` describes its current slot.
    public func descended(stableIdentifier: String, index: Int) -> SBJEditTraversalContext {
        SBJEditTraversalContext(
            treeLevel: treeLevel + 1,
            itemIdentifier: itemIdentifier.appending("item:\(stableIdentifier)"),
            indexPath: indexPath.appending("index:\(index)"),
            navigationPath: navigationPath + ["[\(index)]"]
        )
    }

    public func descended(dictionaryKey key: String) -> SBJEditTraversalContext {
        SBJEditTraversalContext(
            treeLevel: treeLevel + 1,
            itemIdentifier: itemIdentifier.appending("key:\(key)"),
            indexPath: indexPath.appending("key:\(key)"),
            navigationPath: navigationPath + [key]
        )
    }

    public func descended() -> SBJEditTraversalContext {
        SBJEditTraversalContext(
            treeLevel: treeLevel + 1,
            itemIdentifier: itemIdentifier.appending("level:\(treeLevel + 1)"),
            indexPath: indexPath.appending("level:\(treeLevel + 1)"),
            navigationPath: navigationPath
        )
    }

}
