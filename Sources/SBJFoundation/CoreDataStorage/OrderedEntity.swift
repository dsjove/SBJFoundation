import Foundation

public enum MoveDirection: Sendable {
    case up
    case down
}

public enum MoveRelativeTo<Element> {
    case first
    case before(Element)
    case after(Element)
    case last
}

/// Describes a hierarchical insertion/reparenting position without imposing a
/// particular persistence technology on the element.
public enum OrderedRelationship<Element> {
    case child(Element)
    case before(Element)
    case after(Element)

    public var element: Element {
        switch self {
        case .child(let element), .before(let element), .after(let element): element
        }
    }
}

/// A reference-semantic model that participates in a sibling ordering.
///
/// Implementers provide their current sibling set; Foundation owns the stable
/// ordering and mutation mechanics so apps do not each carry a copy.
public protocol OrderedEntity: Comparable, AnyObject {
    var order: Int { get set }
    var siblingCount: Int { get }
    var sortedSiblings: [Self] { get }
}

public extension OrderedEntity {
    var hasSiblings: Bool { siblingCount > 1 }
    var lastOrder: Int { siblingCount * 10 }
    var index: Int { order / 10 }
    var isFirst: Bool { order <= 10 }
    var isLast: Bool { order >= lastOrder }
    var insertPrevOrder: Int { order - 5 }
    var insertNextOrder: Int { order + 5 }

    func move(_ direction: MoveDirection) {
        guard siblingCount > 1 else { return }
        let siblings = sortedSiblings
        guard let index = siblings.firstIndex(where: { $0 === self }) else { return }

        let targetIndex: Int
        switch direction {
        case .up:
            targetIndex = index == 0 ? siblings.count - 1 : index - 1
        case .down:
            targetIndex = index == siblings.count - 1 ? 0 : index + 1
        }
        swap(&order, &siblings[targetIndex].order)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.order != rhs.order { return lhs.order < rhs.order }
        return ObjectIdentifier(lhs) < ObjectIdentifier(rhs)
    }
}

public extension Array where Element: OrderedEntity & Identifiable {
    func moveOrdered(_ object: Element, positioned: MoveRelativeTo<Element> = .last) {
        object.order = provisionalOrder(for: positioned)
        normalizeOrder()
    }

    mutating func addOrdered(_ object: Element, positioned: MoveRelativeTo<Element> = .last) {
        object.order = provisionalOrder(for: positioned)
        addIdentified(object)
        normalizeOrder()
    }

    mutating func removeOrdered(_ object: Element) {
        removeIdentified(object)
        normalizeOrder()
    }

    var orderedFirst: Element? { self.min(by: { $0.order < $1.order }) }
    var orderedLast: Element? { self.max(by: { $0.order < $1.order }) }

    func normalizeOrder() {
        for (index, item) in sorted().enumerated() {
            item.order = (index + 1) * 10
        }
    }

    private func provisionalOrder(for position: MoveRelativeTo<Element>) -> Int {
        switch position {
        case .first: 0
        case .before(let sibling): sibling.insertPrevOrder
        case .after(let sibling): sibling.insertNextOrder
        case .last: Int.max
        }
    }
}
