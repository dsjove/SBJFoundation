import Foundation
import Testing
@testable import SBJDocuments

private final class OrderedTestItem: OrderedEntity, Identifiable {
    let id = UUID()
    var order: Int
    weak var owner: OrderedTestOwner?

    init(order: Int = 0, owner: OrderedTestOwner? = nil) {
        self.order = order
        self.owner = owner
    }

    static func == (lhs: OrderedTestItem, rhs: OrderedTestItem) -> Bool {
        lhs.id == rhs.id
    }

    var siblingCount: Int { owner?.items.count ?? 1 }
    var sortedSiblings: [OrderedTestItem] { owner?.items.sorted() ?? [self] }
}

private final class OrderedTestOwner {
    var items: [OrderedTestItem] = []

    func add(_ item: OrderedTestItem, positioned: MoveRelativeTo<OrderedTestItem> = .last) {
        item.owner = self
        items.addOrdered(item, positioned: positioned)
    }
}

@Test func orderedInsertionNormalizesSpacing() {
    let owner = OrderedTestOwner()
    let a = OrderedTestItem(); let b = OrderedTestItem(); let c = OrderedTestItem()
    owner.add(a); owner.add(c); owner.add(b, positioned: .before(c))
    #expect(owner.items.sorted().map(\.id) == [a.id, b.id, c.id])
    #expect(owner.items.sorted().map(\.order) == [10, 20, 30])
}

@Test func orderedMoveWrapsAtEnds() {
    let owner = OrderedTestOwner()
    let a = OrderedTestItem(); let b = OrderedTestItem(); let c = OrderedTestItem()
    owner.add(a); owner.add(b); owner.add(c)
    a.move(.up)
    #expect(owner.items.sorted().map(\.id) == [c.id, b.id, a.id])
    a.move(.down)
    #expect(owner.items.sorted().map(\.id) == [a.id, b.id, c.id])
}
