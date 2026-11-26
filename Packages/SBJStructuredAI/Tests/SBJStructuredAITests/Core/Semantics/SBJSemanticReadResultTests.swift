import Foundation
import Testing
@testable import SBJStructuredAI

// Typed inspection conveniences used only by the semantic tests.
extension SBJSemanticReadResult {
    var readValue: SBJSemanticValue? {
        if case .value(let read) = self { return read.value }
        return nil
    }
    var state: State? {
        switch self {
        case .status(let state): return state
        case .value(let read): return read.state
        default: return nil
        }
    }
    var failure: String? {
        switch self {
        case .error(let message): return message
        case .memberRequired(let request): return request.reason
        default: return nil
        }
    }
    var metadata: SBJSemanticValue? {
        if case .description(let metadata) = self { return metadata }
        return nil
    }
    var memberRequest: MemberRequest? {
        if case .memberRequired(let request) = self { return request }
        return nil
    }
    var available: CollectionKeys? {
        switch self {
        case .keys(let keys): return keys
        case .memberRequired(let request): return request.available
        default: return nil
        }
    }
    var countValue: Int? {
        if case .count(let count) = self { return count.count }
        return nil
    }
    var memberCount: Int? {
        if case .count(let count) = self { return count.memberCount }
        return nil
    }
    var childrenPage: Children? {
        if case .children(let page) = self { return page }
        return nil
    }
}

@Suite("EBNF read tool output")
struct SBJSemanticReadResultTests {
    private func read(_ value: SBJSemanticValue, state: SBJSemanticReadResult.State? = nil) -> SBJSemanticReadResult {
        .value(.init(value: value, title: "Ignored for model output", state: state, count: nil, memberCount: nil))
    }

    @Test func scalarValuesRemainExact() {
        #expect(read(.signed(24)).promptText == "value:24")
        #expect(read(.unsigned(.max)).promptText == "value:18446744073709551615")
        #expect(read(.decimal(Decimal(string: "1234567890.123456789")!)).promptText == "value:1234567890.123456789")
        #expect(read(.bool(false)).promptText == "value:false")
        #expect(read(.text("42")).promptText == "value:\"42\"")
        #expect(read(.number(.infinity)).promptText == "value:\"inf\"")
    }

    @Test func statesRemainDistinct() {
        #expect(read(.null, state: .unset).promptText == "status:unset")
        #expect(read(.array([]), state: .empty).promptText == "value:[];status:empty")
        #expect(read(.signed(0)).promptText == "value:0")
        #expect(SBJSemanticReadResult.status(.inactive).promptText == "status:inactive")
        #expect(SBJSemanticReadResult.status(.missing).promptText == "status:missing")
        #expect(SBJSemanticReadResult.error("Invalid key").promptText == "error:\"Invalid key\"")
    }

    @Test func availableKeysAndNegotiation() {
        let keys = SBJSemanticReadResult.CollectionKeys(members: [.init(key: "Pebble", title: nil), .init(key: "@2", title: "Granite")], unaddressableCount: 0)
        #expect(SBJSemanticReadResult.keys(keys).promptText == "keys:Pebble,@2=Granite")
        #expect(SBJSemanticReadResult.keys(.init(members: [], unaddressableCount: 0)).promptText == "keys:")
        #expect(SBJSemanticReadResult.keys(.init(members: [], unaddressableCount: 2)).promptText == "keys:;unaddressable:2")
        #expect(SBJSemanticReadResult.memberRequired(.init(action: .insert, keyPosition: 3, collectionID: 42, available: keys, reason: "Missing member")).promptText == "memberRequired:insert:3;keys:Pebble,@2=Granite")
        #expect(SBJSemanticReadResult.memberRequired(.init(action: .replace, keyPosition: 3, collectionID: 42, available: keys, reason: "Invalid member")).promptText == "memberRequired:replace:3;keys:Pebble,@2=Granite")
    }

    @Test func quotedKeysAndStructuredData() {
        let keys = SBJSemanticReadResult.CollectionKeys(members: [.init(key: "Red, Blue", title: "A=B"), .init(key: "@3", title: "Line\nBreak"), .init(key: "", title: nil)], unaddressableCount: 0)
        #expect(SBJSemanticReadResult.keys(keys).promptText == #"keys:"Red, Blue"="A=B",@3="Line\nBreak","""#)
        let data: SBJSemanticValue = .object(["b": .array([.null, .text("a\"b\\c\n")]), "a": .bool(true)])
        #expect(read(data).promptText == #"value:{"a"=true;"b"=[null,"a\"b\\c\n"]}"#)
    }
}
