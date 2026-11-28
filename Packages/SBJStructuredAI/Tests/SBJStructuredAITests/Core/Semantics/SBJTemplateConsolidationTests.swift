import SBJStructure
import Testing
@testable import SBJStructuredAI

@SBJStructure
private struct DuckA {
    var meaningfulPropertyName: Int = 0
    var anotherMeaningfulPropertyName: String = ""
}

@SBJStructure
private struct DuckB {
    var meaningfulPropertyName: Int = 1
    var anotherMeaningfulPropertyName: String = "different instance value"
}

@SBJStructure
private struct DifferentLeafTypeDuck {
    var meaningfulPropertyName: String = ""
    var anotherMeaningfulPropertyName: String = ""
}

@SBJStructure
private struct DuckRoot {
    var first = DuckA()
    var second = DuckB()
    var third = DifferentLeafTypeDuck()
}

@Suite("Declared template equivalence")
struct SBJTemplateConsolidationTests {
    @Test func productionProjectionSharesIdenticalCompressedDefinitions() throws {
        let projection = try SBJStaticReadStructure(type: DuckRoot.self)
        #expect(projection.compact.contains("First:2+#1"))
        #expect(projection.compact.contains("Second:5+#1"))
        #expect(projection.compact.contains("Third:6+#1"))
        #expect(try SBJCompactStructureTestDecoder.expand(projection.compact) == projection.expanded)
    }

    @Test func sharedIDResolvesDistinctPathsAndMetadata() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: DuckRoot())
        let first = try #require(snapshot.declarationIdentifier(for: [.field("first"), .field("meaningfulPropertyName")]))
        let second = try #require(snapshot.declarationIdentifier(for: [.field("second"), .field("meaningfulPropertyName")]))
        let third = try #require(snapshot.declarationIdentifier(for: [.field("third"), .field("meaningfulPropertyName")]))
        #expect(first == second && second == third)
        let firstParent = try #require(snapshot.declarationIdentifier(for: [.field("first")]))
        let secondParent = try #require(snapshot.declarationIdentifier(for: [.field("second")]))
        let thirdParent = try #require(snapshot.declarationIdentifier(for: [.field("third")]))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(first)]).failure != nil)
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(firstParent), .field(first)]).readValue == .signed(0))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(secondParent), .field(first)]).readValue == .signed(1))
        #expect(try snapshot.modelQuery(.describe, keyPath: [.field(thirdParent), .field(first)]).metadata?["type"] == .text("String"))
    }
}

@SBJStructure
private struct RepeatedDuckRoot {
    var first = DuckA()
    var second = DuckA()
    var third: [DuckA] = []
}

extension SBJTemplateConsolidationTests {
    @Test func repeatedTypeCreatesTemplate() throws {
        let projection = try SBJStaticReadStructure(type: RepeatedDuckRoot.self)
        #expect(projection.compact.contains("First:2+#1"))
        #expect(projection.compact.contains("Second:5+#1"))
        #expect(try SBJCompactStructureTestDecoder.expand(projection.compact) == projection.expanded)
    }
}

@SBJStructure
private struct OptionalDuckRoot {
    var absent: DuckA? = nil
    var present: DuckA? = DuckA(meaningfulPropertyName: 19)
}

extension SBJTemplateConsolidationTests {
    @Test func sharedOptionalPathDoesNotReadAnotherOccurrence() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: OptionalDuckRoot())
        let field = try #require(snapshot.declarationIdentifier(for: [.field("absent"), .field("meaningfulPropertyName")]))
        #expect(field == snapshot.declarationIdentifier(for: [.field("present"), .field("meaningfulPropertyName")]))
        let absent = try #require(snapshot.declarationIdentifier(for: [.field("absent")]))
        let present = try #require(snapshot.declarationIdentifier(for: [.field("present")]))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(absent), .field(field)]).state == .unset)
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(present), .field(field)]).readValue == .signed(19))
        #expect(try snapshot.modelQuery(.describe, keyPath: [.field(absent), .field(field)]).metadata?["type"] == .text("Int"))
    }
}

@SBJStructure
private struct NestedDuck {
    var inner = DuckA()
    var enabled = true
}

@SBJStructure
private struct NestedDuckRoot {
    var first = NestedDuck()
    var second = NestedDuck(inner: DuckA(meaningfulPropertyName: 41))
    var standalone = DuckA(meaningfulPropertyName: 82)
}

extension SBJTemplateConsolidationTests {
    @Test func nestedSharedFieldsResolveThroughEachAncestor() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: NestedDuckRoot())
        let first = try #require(snapshot.declarationIdentifier(for: [.field("first")]))
        let second = try #require(snapshot.declarationIdentifier(for: [.field("second")]))
        let standalone = try #require(snapshot.declarationIdentifier(for: [.field("standalone")]))
        let inner = try #require(snapshot.declarationIdentifier(for: [.field("first"), .field("inner")]))
        let value = try #require(snapshot.declarationIdentifier(for: [.field("first"), .field("inner"), .field("meaningfulPropertyName")]))
        #expect(inner == snapshot.declarationIdentifier(for: [.field("second"), .field("inner")]))
        #expect(value == snapshot.declarationIdentifier(for: [.field("standalone"), .field("meaningfulPropertyName")]))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(first), .field(inner), .field(value)]).readValue == .signed(0))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(second), .field(inner), .field(value)]).readValue == .signed(41))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(standalone), .field(value)]).readValue == .signed(82))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(second), .field(value)]).failure != nil)
    }
}
