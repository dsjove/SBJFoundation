import SBJDataDefinition
#if !os(tvOS) && !os(watchOS)
import SBJUIVocabulary
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

/// Explicit, immutable state for a single editor branch/row.
/// This is intentionally not an EnvironmentValue: consumers receive it through
/// their initializers, while descendants inherit search criteria but not status.
public enum SBJEditorRowPlacement: Hashable, Sendable {
    case normal
    case embedded
    case contentOnly
}

public struct SBJEditorRowStatus: Hashable, Sendable {
    public var isChanged: Bool
    public var hasContent: Bool?
    public var isInvalid: Bool

    public init(isChanged: Bool = false, hasContent: Bool? = nil, isInvalid: Bool = false) {
        self.isChanged = isChanged
        self.hasContent = hasContent
        self.isInvalid = isInvalid
    }
}

public enum SBJEditorPropertyInfoPlacement: Hashable, Sendable {
    case overlay
    case inline
    case hidden
}

public struct SBJEditorBranchContext: Hashable, Sendable {
    public var searchCriteria: SBJStructuralSearchCriteria
    public var placement: SBJEditorRowPlacement
    public var status: SBJEditorRowStatus
    public var disclosureMode: SBJEditorDisclosureMode
    public var propertyInfoPlacement: SBJEditorPropertyInfoPlacement

    public init(
        searchCriteria: SBJStructuralSearchCriteria = .init(),
        placement: SBJEditorRowPlacement = .normal,
        status: SBJEditorRowStatus = .init(),
        disclosureMode: SBJEditorDisclosureMode = .closed,
        propertyInfoPlacement: SBJEditorPropertyInfoPlacement = .overlay
    ) {
        self.searchCriteria = searchCriteria
        self.placement = placement
        self.status = status
        self.disclosureMode = disclosureMode
        self.propertyInfoPlacement = propertyInfoPlacement
    }

    public func withSearchCriteria(_ criteria: SBJStructuralSearchCriteria) -> Self {
        var result = self
        result.searchCriteria = criteria
        return result
    }

    public func withPlacement(_ placement: SBJEditorRowPlacement) -> Self {
        var result = self
        result.placement = placement
        return result
    }

    public func withStatus(_ status: SBJEditorRowStatus) -> Self {
        var result = self
        result.status = status
        return result
    }

    public func withDisclosureMode(_ mode: SBJEditorDisclosureMode) -> Self {
        var result = self
        result.disclosureMode = mode
        return result
    }

    public func withPropertyInfoPlacement(_ placement: SBJEditorPropertyInfoPlacement) -> Self {
        var result = self
        result.propertyInfoPlacement = placement
        return result
    }

    public var child: Self {
        .init(searchCriteria: searchCriteria)
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
    public let branch: SBJEditorBranchContext

    public init(
        treeLevel: Int = 0,
        itemIdentifier: SBJEditorItemIdentifier = .root,
        indexPath: SBJEditorIndexPath = .root,
        navigationPath: [String] = [],
        branch: SBJEditorBranchContext = .init()
    ) {
        precondition(treeLevel >= 0, "treeLevel cannot be negative")
        self.treeLevel = treeLevel
        self.itemIdentifier = itemIdentifier
        self.indexPath = indexPath
        self.navigationPath = navigationPath
        self.branch = branch
    }

    public static let root = SBJEditTraversalContext()

    /// Identifies a property at the current visual level.
    public func property(_ name: String) -> SBJEditTraversalContext {
        SBJEditTraversalContext(
            treeLevel: treeLevel,
            itemIdentifier: itemIdentifier.appending("property:\(name)"),
            indexPath: indexPath.appending("property:\(name)"),
            navigationPath: navigationPath + [name],
            branch: branch.child
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
            navigationPath: navigationPath + ["[\(index)]"],
            branch: branch.child
        )
    }

    public func descended(dictionaryKey key: String) -> SBJEditTraversalContext {
        SBJEditTraversalContext(
            treeLevel: treeLevel + 1,
            itemIdentifier: itemIdentifier.appending("key:\(key)"),
            indexPath: indexPath.appending("key:\(key)"),
            navigationPath: navigationPath + [key],
            branch: branch.child
        )
    }

    public func descended() -> SBJEditTraversalContext {
        SBJEditTraversalContext(
            treeLevel: treeLevel + 1,
            itemIdentifier: itemIdentifier.appending("level:\(treeLevel + 1)"),
            indexPath: indexPath.appending("level:\(treeLevel + 1)"),
            navigationPath: navigationPath,
            branch: branch.child
        )
    }

    /// Rebase a projected node onto its parent-assigned visual level.
    /// The tree projection owns hierarchy depth; identity and navigation paths
    /// are unchanged by this visual normalization.
    public func atTreeLevel(_ level: Int) -> Self {
        .init(treeLevel: level, itemIdentifier: itemIdentifier,
              indexPath: indexPath, navigationPath: navigationPath, branch: branch)
    }

    public func withBranch(_ updated: SBJEditorBranchContext) -> Self {
        .init(treeLevel: treeLevel, itemIdentifier: itemIdentifier, indexPath: indexPath, navigationPath: navigationPath, branch: updated)
    }

}
#endif
