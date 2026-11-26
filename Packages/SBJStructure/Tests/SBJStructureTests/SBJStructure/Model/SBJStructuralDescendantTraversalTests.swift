import XCTest
@testable import SBJStructure

@SBJStructure
private struct DescendantChild: Codable {
    var score: Int
    let note: String

    init(score: Int = 12) {
        self.score = score
        self.note = "read-only"
    }
}

@SBJStructure
private struct DescendantRoot: Codable {
    var title: String = "Example"
    var child: DescendantChild = .init()
    var optional: DescendantChild? = .init()
    var children: [DescendantChild] = [.init(), .init(score: 14)]
    var mapping: [String: DescendantChild] = ["first": .init()]
    var labels: Set<String> = ["hero"]
}

@SBJStructure
private struct IdentifiedDescendant: Codable {
    var id: String
    var score: Int
}

final class SBJStructuralDescendantTraversalTests: XCTestCase {
    func testStoredDeclarationOrderIsPreservedInEveryNestedStructure() {
        let occurrences = SBJStructuralTraversal.descendants(in: DescendantRoot())
        let rootProperties = occurrences.filter { $0.identityPath.count == 1 && $0.identityPath[0].hasPrefix("property:") }
        XCTAssertEqual(rootProperties.map(\.identityPath), [
            ["property:title"], ["property:child"], ["property:optional"],
            ["property:children"], ["property:mapping"], ["property:labels"]
        ])
        let childProperties = occurrences.filter {
            $0.identityPath.count == 2 && $0.identityPath.first == "property:child"
        }
        XCTAssertEqual(childProperties.map(\.identityPath), [
            ["property:child", "property:score"],
            ["property:child", "property:note"]
        ])
        XCTAssertEqual(childProperties.map(\.locationPath), [
            ["field:1", "field:0"], ["field:1", "field:1"]
        ])
    }

    func testArrayDictionaryAndOptionalRetainCompleteAncestry() throws {
        let occurrences = SBJStructuralTraversal.descendants(in: DescendantRoot())
        let second = try XCTUnwrap(occurrences.first {
            $0.identityPath == ["property:children", "item:slot:1", "property:score"]
        })
        XCTAssertEqual(second.locationPath, ["field:3", "index:1", "field:0"])
        XCTAssertEqual(second.displayPath.count, 3)
        XCTAssertTrue(second.isPositional)
        let dictionary = try XCTUnwrap(occurrences.first {
            $0.identityPath == ["property:mapping", "key:\"first\"", "property:score"]
        })
        XCTAssertEqual(dictionary.locationPath.count, 3)
        XCTAssertEqual(dictionary.displayPath.count, 3)
        XCTAssertFalse(dictionary.isPositional)
        let optional = try XCTUnwrap(occurrences.first {
            $0.identityPath == ["property:optional", "property:score"]
        })
        XCTAssertEqual(optional.locationPath, ["field:2", "field:0"])
        XCTAssertFalse(optional.isPositional)
    }

    func testNestedFieldsIncludeImmutablePropertiesAndTypedValues() {
        XCTAssertEqual(DescendantChild.sbjSwiftWritablePropertyNames, ["score"])
        let occurrences = SBJStructuralTraversal.descendants(in: DescendantRoot())
        let nested = occurrences.first { $0.identityPath == ["property:child", "property:score"] }
        XCTAssertEqual(nested?.value as? Int, 12)
        XCTAssertEqual(nested?.displayPath.count, 2)
        XCTAssertTrue(nested?.isWritableProperty == true)

        let immutable = occurrences.first { $0.identityPath == ["property:child", "property:note"] }
        XCTAssertEqual(immutable?.value as? String, "read-only")
        XCTAssertEqual(immutable?.isWritableProperty, false)
    }

    func testOptionalContentsPreserveParentIdentity() {
        let occurrences = SBJStructuralTraversal.descendants(in: DescendantRoot())
        XCTAssertNotNil(occurrences.first {
            $0.identityPath == ["property:optional", "property:score"]
        })
        var model = DescendantRoot()
        model.optional = nil
        let absent = SBJStructuralTraversal.descendants(in: model)
        XCTAssertFalse(absent.contains { $0.identityPath == ["property:optional", "property:score"] })
    }

    func testArrayAndDictionaryFieldsAreAddressable() {
        let occurrences = SBJStructuralTraversal.descendants(in: DescendantRoot())
        let scores = occurrences.filter { $0.identityPath.last == "property:score" }
        XCTAssertTrue(scores.contains { $0.identityPath.contains("item:slot:0") && ($0.value as? Int) == 12 })
        XCTAssertTrue(scores.contains { $0.identityPath.contains("item:slot:1") && ($0.value as? Int) == 14 })
        XCTAssertTrue(scores.contains { $0.identityPath.contains("key:\"first\"") })
        XCTAssertTrue(scores.filter { $0.identityPath.contains("item:slot:0") }.allSatisfy(\.isPositional))
    }

    func testStableCollectionIdentityFollowsReorder() {
        let first = IdentifiedDescendant(id: "alpha", score: 10)
        let second = IdentifiedDescendant(id: "beta", score: 20)
        let before = SBJStructuralValueWalker.children(
            of: [first, second], identityPath: ["property:items"],
            locationPath: ["field:0"], displayPath: ["Items"],
            isPositional: false, ancestorsWritable: true, itemIdentifierKey: "id"
        )
        let after = SBJStructuralValueWalker.children(
            of: [second, first], identityPath: ["property:items"],
            locationPath: ["field:0"], displayPath: ["Items"],
            isPositional: false, ancestorsWritable: true, itemIdentifierKey: "id"
        )
        let beforeAlpha = before.first { ($0.value as? IdentifiedDescendant)?.id == "alpha" }
        let afterAlpha = after.first { ($0.value as? IdentifiedDescendant)?.id == "alpha" }
        XCTAssertNotNil(beforeAlpha)
        XCTAssertEqual(beforeAlpha?.identityPath, afterAlpha?.identityPath)
        XCTAssertNotEqual(beforeAlpha?.locationPath, afterAlpha?.locationPath)
        XCTAssertEqual(beforeAlpha?.isPositional, false)
    }

    func testImmutableAncestorMakesNestedFieldsReadOnly() {
        let child = DescendantChild()
        let occurrences = child.sbjStructuralDescendants(
            identityPath: ["property:immutable"],
            locationPath: ["field:0"],
            displayPath: ["Immutable"],
            isPositional: false,
            ancestorsWritable: false
        )
        XCTAssertTrue(occurrences.allSatisfy { !$0.isWritableProperty })
    }

    func testVisitorAgreesWithCollectedDescendants() {
        let model = DescendantRoot()
        let expected = SBJStructuralTraversal.descendants(in: model).map(\.identityPath)
        var visited: [[String]] = []
        SBJStructuralTraversal.visitDescendants(in: model) { visited.append($0.identityPath) }
        XCTAssertEqual(visited, expected)
    }

    func testCollectionKeysFollowSamePolicyAsEditor() {
        XCTAssertNil(SBJStructuralCollectionKeys.title(in: []))
        XCTAssertNil(SBJStructuralCollectionKeys.identifier(in: []))
        XCTAssertEqual(SBJStructuralCollectionKeys.title(in: [.elementName(\IdentifiedDescendant.id)]), \IdentifiedDescendant.id)
        XCTAssertEqual(SBJStructuralCollectionKeys.identifier(in: [.uniqueBy("element.id")]), "id")
    }
}
