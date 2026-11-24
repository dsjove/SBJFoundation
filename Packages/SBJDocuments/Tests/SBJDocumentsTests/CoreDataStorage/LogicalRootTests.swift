import SwiftData
import Testing
@testable import SBJDocuments

@Model
private final class TestLogicalRoot {
    var identity: String
    var contentCount: Int

    init(identity: String, contentCount: Int) {
        self.identity = identity
        self.contentCount = contentCount
    }
}

@Suite("SwiftData logical root reconciliation")
@MainActor
struct LogicalRootTests {
    private func makeContext() throws -> ModelContext {
        let container = try CoreDataStorage.makeModelContainer(
            for: [TestLogicalRoot.self], version: .init(1, 0, 0), inMemory: true
        )
        return ModelContext(container)
    }

    @Test("Creates exactly one logical root when the store is empty")
    func createsRoot() throws {
        let context = try makeContext()
        let resolution = try CoreDataStorage.ensureLogicalRoot(
            TestLogicalRoot.self,
            in: context,
            canonicalKey: { $0.identity },
            create: { TestLogicalRoot(identity: "root", contentCount: 2) },
            merge: { _, _ in }
        )

        #expect(resolution.root.identity == "root")
        #expect(resolution.duplicateCount == 0)
        #expect(try context.fetch(FetchDescriptor<TestLogicalRoot>()).count == 1)
    }

    @Test("Merges duplicate roots and remains stable on a second reconciliation")
    func mergesAndConverges() throws {
        let context = try makeContext()
        context.insert(TestLogicalRoot(identity: "b", contentCount: 3))
        context.insert(TestLogicalRoot(identity: "a", contentCount: 2))
        try context.save()

        func reconcile() throws -> LogicalRootResolution<TestLogicalRoot> {
            try CoreDataStorage.ensureLogicalRoot(
                TestLogicalRoot.self,
                in: context,
                canonicalKey: { $0.identity },
                create: { TestLogicalRoot(identity: "new", contentCount: 0) },
                merge: { duplicate, canonical in
                    canonical.contentCount += duplicate.contentCount
                }
            )
        }

        let first = try reconcile()
        #expect(first.root.identity == "a")
        #expect(first.root.contentCount == 5)
        #expect(first.duplicateCount == 1)

        let second = try reconcile()
        #expect(second.root.identity == "a")
        #expect(second.root.contentCount == 5)
        #expect(second.duplicateCount == 0)
        #expect(try context.fetch(FetchDescriptor<TestLogicalRoot>()).count == 1)
    }
}
