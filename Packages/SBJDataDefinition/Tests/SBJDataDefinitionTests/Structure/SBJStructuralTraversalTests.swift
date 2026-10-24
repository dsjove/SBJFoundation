import XCTest
@testable import SBJDataDefinition

@SBJStructure
private struct TraversedModel: Codable {
    var first: String = "A"
    var second: Int = 2
}

@SBJStructure
private struct ImmutableModel: Codable {
    let identifier: UUID
    var title: String
}

private final class CapturingPropertyVisitor: SBJTypedStructuralPropertyVisitor {
    typealias Root = TraversedModel
    var visitedTypes: [String] = []
    var visitedSourceNames: [String] = []
    var observedValues: [String] = []
    var model = TraversedModel()

    func visit<Value: Codable>(
        _ keyPath: WritableKeyPath<TraversedModel, Value>,
        metadata: SBJPropertyMetadata<TraversedModel>?
    ) {
        visitedTypes.append(String(reflecting: Value.self))
        visitedSourceNames.append(metadata?.sourceName ?? "missing")
        observedValues.append(String(describing: model[keyPath: keyPath]))
    }
}

final class SBJStructuralTraversalTests: XCTestCase {
    func testTypedVisitorPreservesDeclaredValueTypes() {
        let visitor = CapturingPropertyVisitor()
        for location in SBJStructuralTraversal.schema(of: TraversedModel.self) {
            XCTAssertTrue(location.property.visitTypedProperty(with: visitor))
        }
        XCTAssertEqual(visitor.visitedTypes, [String(reflecting: String.self), String(reflecting: Int.self)])
        XCTAssertEqual(visitor.visitedSourceNames, ["first", "second"])
        XCTAssertEqual(visitor.observedValues, ["A", "2"])
    }

    func testDefinitionIncludesImmutablePropertiesWithoutInstance() {
        let properties = SBJStructuralTraversal.definition(of: ImmutableModel.self)
        XCTAssertEqual(properties.map(\.sourceName), ["identifier", "title"])
        XCTAssertEqual(properties.map(\.displayName), ["Identifier", "Title"])
        XCTAssertEqual(properties.map(\.identityComponent), ["property:identifier", "property:title"])
        XCTAssertEqual(properties.map(\.locationComponent), ["field:0", "field:1"])
        XCTAssertTrue(properties[0].valueType == UUID.self)
        XCTAssertTrue(properties[1].valueType == String.self)
        XCTAssertEqual(properties[0].metadata.sourceName, "identifier")
        var visited: [String] = []
        SBJStructuralTraversal.visitDefinition(of: ImmutableModel.self) { visited.append($0.sourceName) }
        XCTAssertEqual(visited, ["identifier", "title"])
    }

    func testWritableSchemaAgreesWithCompleteDefinition() {
        let full = SBJStructuralTraversal.definition(of: TraversedModel.self)
        let writable = SBJStructuralTraversal.schema(of: TraversedModel.self)
        XCTAssertEqual(full.map(\.identityComponent), writable.map(\.identityComponent))
        XCTAssertEqual(full.map(\.sourceName), writable.map(\.sourceName))
    }

    func testPropertyOrderAndStableLocation() {
        let nodes = SBJStructuralTraversal.properties(of: TraversedModel.self)
        XCTAssertEqual(nodes.map(\.sourceName), ["first", "second"])
        XCTAssertEqual(nodes.map(\.displayName), ["First", "Second"])
        XCTAssertEqual(nodes.map(\.name), ["First", "Second"])
        XCTAssertEqual(nodes.map(\.locationComponent), ["field:0", "field:1"])
        XCTAssertEqual(nodes.map(\.identityComponent), ["property:first", "property:second"])
    }

    func testPropertyCanMutateItsRoot() {
        let nodes = SBJStructuralTraversal.properties(of: TraversedModel.self)
        var model = TraversedModel()
        XCTAssertTrue(nodes[1].property.setValue(3, in: &model))
        XCTAssertEqual(model.second, 3)
        XCTAssertFalse(nodes[1].property.setValue("invalid", in: &model))
    }

    func testSchemaIsAvailableWithoutInstance() {
        let schema = SBJStructuralTraversal.schema(of: TraversedModel.self)
        XCTAssertEqual(schema.map(\.sourceName), ["first", "second"])
        XCTAssertTrue(schema[0].valueType == String.self)
        XCTAssertTrue(schema[1].valueType == Int.self)
        XCTAssertNotNil(schema[0].metadata)
        XCTAssertEqual(schema[0].metadata?.sourceName, "first")

        var visited: [String] = []
        SBJStructuralTraversal.visitSchema(of: TraversedModel.self) {
            visited.append($0.identityComponent)
        }
        XCTAssertEqual(visited, ["property:first", "property:second"])
    }

    func testSchemaAndValueTraversalHaveSameLocations() {
        var visited: [(String, String)] = []
        SBJStructuralTraversal.visitValues(in: TraversedModel()) { location, value in
            visited.append((location.sourceName, String(describing: value)))
        }
        XCTAssertEqual(visited.map(\.0), ["first", "second"])
        XCTAssertEqual(visited.map(\.1), ["A", "2"])
    }

    func testTypedValueAndWritableKeyPathRequireExactType() {
        let property = SBJStructuralTraversal.schema(of: TraversedModel.self)[0].property
        var model = TraversedModel()
        XCTAssertEqual(property.withTypedValue(in: model, as: String.self) { $0 }, "A")
        XCTAssertNil(property.withTypedValue(in: model, as: Int.self) { $0 })
        let result = property.withWritableKeyPath(as: String.self) { keyPath -> String in
            model[keyPath: keyPath] = "Changed"
            return model[keyPath: keyPath]
        }
        XCTAssertEqual(result, "Changed")
        XCTAssertNil(property.withWritableKeyPath(as: Int.self) { _ in true })
    }

}
