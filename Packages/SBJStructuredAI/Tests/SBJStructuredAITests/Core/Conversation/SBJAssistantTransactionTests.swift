import Foundation
import SBJLocalization
import SBJStructure
import Testing
@testable import SBJStructuredAI

@SBJStructure
struct SBJTransactionFixture {
    @SBJInteger(range: 1...20)
    var level = 9
    let fixed = "Fixed"
}

@Suite("Assistant mutation transactions")
@MainActor
struct SBJAssistantTransactionTests {
    private typealias Transaction = SBJAssistantTransaction<SBJTransactionFixture>
    @MainActor
    private final class Host {
        var document: SBJAssistantDocument<SBJTransactionFixture>? = .init(id: "doc", revision: 1, model: .init(), allowsEditing: true)
        var calls = 0
        var candidate: SBJTransactionFixture?
        var finish: (@MainActor (Result<Void, Error>) -> Void)?
        func transaction() -> Transaction {
            Transaction(snapshot: { self.document }, persist: { model, id, revision, completion in
                self.calls += 1
                #expect(id == self.document?.id)
                #expect(revision == self.document?.revision)
                self.candidate = model
                self.finish = completion
            })
        }
    }
    private func location(_ name: String = "level") throws -> [String] {
        ["field:\(try #require(SBJTransactionFixture.sbjProperties.firstIndex { $0.sourceName == name }))"]
    }
    @discardableResult
    private func stage(_ transaction: Transaction, host: Host, value: Int = 12) throws -> SBJStructuralChangeSummary {
        try transaction.stage(document: #require(host.document), location: location(), replacement: value,
                              changes: [.init(field: "Level", oldValue: "9", proposedValue: String(value))])
    }

    @Test func approvalWaitsForPersistenceAndIsSingleUse() throws {
        let host = Host(), transaction = host.transaction()
        let summary = try stage(transaction, host: host)
        #expect(transaction.summary == summary)
        #expect(transaction.canApprove)
        #expect(host.document?.model.level == 9)
        #expect(host.calls == 0)
        var applied = 0
        transaction.approve { if case .applied = $0 { applied += 1 } }
        #expect(transaction.isPersisting)
        #expect(transaction.summary == nil)
        #expect(host.candidate?.level == 12)
        #expect(applied == 0)
        transaction.approve { _ in Issue.record("Duplicate approval") }
        #expect(host.calls == 1)
        #expect(throws: Transaction.Failure.self) { try stage(transaction, host: host) }
        host.document = .init(id: "doc", revision: 2, model: try #require(host.candidate), allowsEditing: true)
        host.finish?(.success(()))
        host.finish?(.success(()))
        #expect(applied == 1)
        #expect(!transaction.isPersisting)
    }

    @Test func rejectsInvalidImmutableUnchangedAndDuplicateProposals() throws {
        let host = Host(), transaction = host.transaction()
        #expect(throws: (any Error).self) { try stage(transaction, host: host, value: 21) }
        #expect(throws: Transaction.Failure.self) { try stage(transaction, host: host, value: 9) }
        #expect(throws: (any Error).self) {
            try transaction.stage(document: #require(host.document), location: location("fixed"), replacement: "Other",
                                  changes: [.init(field: "Fixed", oldValue: "Fixed", proposedValue: "Other")])
        }
        #expect(transaction.summary == nil)
        try stage(transaction, host: host)
        #expect(throws: Transaction.Failure.self) { try stage(transaction, host: host) }
        if case .rejected? = transaction.reject() {} else { Issue.record("Expected rejection") }
        #expect(transaction.summary == nil)
        #expect(host.calls == 0)
    }

    @Test func staleRevisionAndUnannouncedContentChangesCannotCommit() throws {
        for revision in [1, 2] {
            let host = Host(), transaction = host.transaction()
            try stage(transaction, host: host)
            var model = SBJTransactionFixture()
            model.level = 10
            host.document = .init(id: "doc", revision: revision, model: model, allowsEditing: true)
            #expect(!transaction.canApprove)
            var failed = false
            transaction.approve { if case .failed = $0 { failed = true } }
            #expect(failed)
            #expect(host.calls == 0)
            #expect(transaction.summary == nil)
        }
    }

    @Test func readOnlyAndMissingPersistenceCannotStage() throws {
        let host = Host()
        let readOnly = Transaction(snapshot: { host.document }, persist: nil)
        #expect(throws: Transaction.Failure.self) { try stage(readOnly, host: host) }
        let transaction = host.transaction()
        try stage(transaction, host: host)
        host.document = .init(id: "doc", revision: 1, model: .init(), allowsEditing: false)
        #expect(transaction.synchronize())
        #expect(transaction.summary == nil)
        #expect(throws: Transaction.Failure.self) { try stage(transaction, host: host) }
        #expect(host.calls == 0)
    }

    @Test func saveFailureIsNotAnAppliedChange() throws {
        struct SaveFailure: Error {}
        let host = Host(), transaction = host.transaction()
        try stage(transaction, host: host)
        var failed = false
        transaction.approve { if case .failed = $0 { failed = true } }
        host.finish?(.failure(SaveFailure()))
        #expect(failed)
        #expect(!transaction.isPersisting)
        #expect(transaction.summary == nil)
        #expect(host.document?.model.level == 9)
        try stage(transaction, host: host)
        transaction.discardPending()
        #expect(transaction.summary == nil)
    }
}
