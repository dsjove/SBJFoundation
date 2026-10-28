import SwiftUI
import Testing
@testable import SBJStructuredEditor

@MainActor
@Suite("Array element actions")
struct SBJArrayElementActionsTests {
    @Test("element moves mutate the current bound array")
    func liveActions() {
        var values = ["first", "second", "third"]
        let parent = Binding<[String]>(get: { values }, set: { values = $0 })
        let actions = SBJArrayElementActions.make(
            parent: parent, index: 1, count: 3, canReorder: true,
            resolvedIndex: { values.indices.contains(1) ? 1 : nil }
        )
        #expect(actions.moveUp != nil)
        #expect(actions.moveDown != nil)
        actions.moveUp?()
        #expect(values == ["second", "first", "third"])
        actions.remove?()
        #expect(values == ["second", "third"])
    }

    @Test("array boundaries and policy determine available actions")
    func boundaries() {
        var values = ["one", "two"]
        let binding = Binding<[String]>(get: { values }, set: { values = $0 })
        let first = SBJArrayElementActions.make(parent: binding, index: 0, count: 2, canReorder: true, resolvedIndex: { 0 })
        let last = SBJArrayElementActions.make(parent: binding, index: 1, count: 2, canReorder: true, resolvedIndex: { 1 })
        let disabled = SBJArrayElementActions.make(parent: binding, index: 0, count: 2, canReorder: false, resolvedIndex: { 0 })
        #expect(first.moveUp == nil)
        #expect(first.moveDown != nil)
        #expect(last.moveUp != nil)
        #expect(last.moveDown == nil)
        #expect(disabled.moveUp == nil)
        #expect(disabled.moveDown == nil)
        #expect(values == ["one", "two"])
    }

    @Test("stale rows cannot mutate an unavailable element")
    func staleBinding() {
        var values = ["one", "two"]
        let binding = Binding<[String]>(get: { values }, set: { values = $0 })
        let actions = SBJArrayElementActions.make(parent: binding, index: 1, count: 2, canReorder: true, resolvedIndex: { nil })
        actions.remove?()
        actions.moveUp?()
        #expect(values == ["one", "two"])
    }
}
