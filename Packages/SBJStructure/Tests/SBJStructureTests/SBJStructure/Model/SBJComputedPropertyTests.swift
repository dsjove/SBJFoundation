import XCTest
import Foundation
@testable import SBJStructure

@SBJStructure
private struct ComputedFixture: Codable {
    var score: Int = 16
    enum CodingKeys: String, CodingKey { case score }

    @SBJComputed(showInEditor: true)
    var modifier: Int { (score - 10) / 2 }

    @SBJComputed
    var doubledScore: Int { score * 2 }

    var unannotatedComputed: Int { score + 1 }

    static let modifierNomenclature = SBJNomenclature(
        title: "Ability Modifier", aliases: ["bonus"]
    )
}

final class SBJComputedPropertyTests: XCTestCase {
    func testGeneratedComputedDescriptorsUseNomenclature() {
        let model = ComputedFixture()
        XCTAssertEqual(ComputedFixture.sbjComputedProperties.count, 2)
        let modifier = ComputedFixture.sbjComputedProperties.first { $0.sourceName == "modifier" }
        XCTAssertEqual(modifier?.value(in: model) as? Int, 3)
        XCTAssertEqual(modifier?.info?.title, "Ability Modifier")
        XCTAssertEqual(modifier?.info?.aliases, ["bonus"])
        XCTAssertEqual(modifier?.showInEditor, true)
        XCTAssertEqual(ComputedFixture.sbjComputedProperties.first { $0.sourceName == "doubledScore" }?.showInEditor, false)
    }

    func testComputedFieldsAreReadOnlyOccurrencesNotStoredFields() throws {
        let model = ComputedFixture()
        let occurrences = SBJStructuralTraversal.descendants(in: model)
        let computed = try XCTUnwrap(occurrences.first { $0.identityPath == ["computed:modifier"] })
        XCTAssertEqual(computed.value as? Int, 3)
        XCTAssertFalse(computed.isWritableProperty)
        XCTAssertNil(occurrences.first { $0.identityPath == ["computed:unannotatedComputed"] })
        XCTAssertEqual(ComputedFixture.sbjProperties.map(\.sourceName), ["score"])
        XCTAssertEqual(ComputedFixture.sbjMutableProperties.count, 1)
    }

    func testComputedFieldsAreNotSerialized() throws {
        let text = String(decoding: try JSONEncoder().encode(ComputedFixture()), as: UTF8.self)
        XCTAssertTrue(text.contains("score"))
        XCTAssertFalse(text.contains("modifier"))
        XCTAssertFalse(text.contains("doubledScore"))
    }
}

@SBJStructure
private struct ExtensionComputedFixture: Codable {
    var score: Int = 16
    @SBJComputed var baseDouble: Int { score * 2 }
}

@SBJStructureExtension
extension ExtensionComputedFixture {
    @SBJComputed(showInEditor: true)
    var extensionModifier: Int { (score - 10) / 2 }

    @SBJComputed
    var extensionTriple: Int { score * 3 }

    var ignoredComputed: Int { score + 1 }

    static let extensionModifierNomenclature = SBJNomenclature(
        title: "Extension Modifier", aliases: ["bonus"]
    )
}

final class SBJExtensionComputedPropertyTests: XCTestCase {
    func testPrimaryAndExtensionComputedPropertiesCombine() {
        let properties = ExtensionComputedFixture.sbjComputedProperties
        XCTAssertEqual(properties.map(\.sourceName), ["baseDouble", "extensionModifier", "extensionTriple"])
        XCTAssertEqual(properties.first { $0.sourceName == "extensionModifier" }?.value(in: .init()) as? Int, 3)
        XCTAssertEqual(properties.first { $0.sourceName == "extensionModifier" }?.info?.title, "Extension Modifier")
        XCTAssertEqual(properties.first { $0.sourceName == "extensionModifier" }?.showInEditor, true)
        XCTAssertFalse(properties.contains { $0.sourceName == "ignoredComputed" })
    }

    func testExtensionPropertiesAppearAsReadOnlyDescendants() {
        let descendants = SBJStructuralTraversal.descendants(in: ExtensionComputedFixture())
        let modifier = descendants.first { $0.identityPath == ["computed:extensionModifier"] }
        XCTAssertEqual(modifier?.value as? Int, 3)
        XCTAssertEqual(modifier?.isWritableProperty, false)
    }

    func testExtensionPropertiesAreNotSerialized() throws {
        let text = String(decoding: try JSONEncoder().encode(ExtensionComputedFixture()), as: UTF8.self)
        XCTAssertTrue(text.contains("score"))
        XCTAssertFalse(text.contains("extensionModifier"))
    }
}


extension SBJExtensionComputedPropertyTests {
    func testMultipleExtensionPropertiesAreReadOnlyAndOrderedAfterPrimary() throws {
        let model = ExtensionComputedFixture()
        let descendants = SBJStructuralTraversal.descendants(in: model)
        let computed = descendants.filter { $0.identityPath.last?.hasPrefix("computed:") == true }
        XCTAssertEqual(computed.map { $0.identityPath.last! }, [
            "computed:baseDouble", "computed:extensionModifier", "computed:extensionTriple"
        ])
        XCTAssertTrue(computed.allSatisfy { !$0.isWritableProperty })
        XCTAssertEqual(computed.map { $0.value as? Int }, [32, 3, 48])
        XCTAssertNil(descendants.first { $0.identityPath.last == "computed:ignoredComputed" })
    }

    func testExtensionComputedValuesAreEvaluatedAgainstCurrentInstance() {
        var model = ExtensionComputedFixture()
        let descriptor = ExtensionComputedFixture.sbjComputedProperties.first {
            $0.sourceName == "extensionModifier"
        }
        XCTAssertEqual(descriptor?.value(in: model) as? Int, 3)
        model.score = 20
        XCTAssertEqual(descriptor?.value(in: model) as? Int, 5)
        XCTAssertEqual(ExtensionComputedFixture.sbjProperties.map(\.sourceName), ["score"])
    }

    func testExtensionMetadataDoesNotChangeDecoding() throws {
        let data = Data(#"{"score":22}"#.utf8)
        let model = try JSONDecoder().decode(ExtensionComputedFixture.self, from: data)
        XCTAssertEqual(model.score, 22)
        XCTAssertEqual(model.extensionModifier, 6)
        let encoded = try JSONEncoder().encode(model)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Int])
        XCTAssertEqual(object, ["score": 22])
    }
}
