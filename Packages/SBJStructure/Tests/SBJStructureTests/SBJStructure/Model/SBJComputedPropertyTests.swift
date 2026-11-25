import Foundation
import Testing
@testable import SBJStructure

@SBJStructure
private struct ComputedFixture: Codable {
    var score: Int = 16
    enum CodingKeys: String, CodingKey { case score }
    @SBJInteger(range: 0...10)
    var modifier: Int { (score - 10) / 2 }
    var doubledScore: Int { score * 2 }
    @SBJFieldPresentation(exclude: true)
    var hiddenFromUser: Int { score + 1 }
    @SBJExclude var excluded: Int { score + 2 }
    private var privateValue: Int { score + 3 }
    static let modifierNomenclature = SBJNomenclature(title: "Ability Modifier", aliases: ["bonus"])
}

@SBJStructure
private struct ExtensionComputedFixture: Codable {
    var score: Int = 16
    var baseDouble: Int { score * 2 }
}

@SBJStructureExtension
extension ExtensionComputedFixture {
    @SBJInteger(range: 0...10)
    var extensionModifier: Int { (score - 10) / 2 }
    var extensionTriple: Int { score * 3 }
    var writable: Int {
        get { score }
        set { score = newValue }
    }
    @SBJExclude var ignoredComputed: Int { score + 1 }
    static let extensionModifierNomenclature = SBJNomenclature(title: "Extension Modifier", aliases: ["bonus"])
}

struct SBJComputedPropertyTests {
    @Test func storedAndComputedShareMetadataAndDeclarationOrder() throws {
        let properties = ComputedFixture.sbjProperties
        #expect(properties.map(\.sourceName) == ["score", "modifier", "doubledScore", "hiddenFromUser"])
        let modifier = try #require(properties.first { $0.sourceName == "modifier" })
        #expect(modifier.value(in: .init()) as? Int == 3)
        #expect(modifier.info?.title == "Ability Modifier")
        #expect(modifier.info?.aliases == ["bonus"])
        #expect(modifier.storage == .computed)
        #expect(modifier.access == .readOnly)
        #expect(modifier.constraints == [.integerRules(.init(range: 0...10))])
        #expect(modifier.mutableProperty() == nil)
    }

    @Test func userFacingTraversalUsesUnifiedPathsAndVisibility() {
        let occurrences = SBJStructuralTraversal.descendants(in: ComputedFixture())
        #expect(occurrences.map(\.identityPath) == [["property:score"], ["property:modifier"], ["property:doubledScore"]])
        #expect(occurrences.map(\.isWritableProperty) == [true, false, false])
    }

    @Test func computedMetadataDoesNotChangeCodableShape() throws {
        let bytes = try JSONEncoder().encode(ComputedFixture())
        #expect(try JSONSerialization.jsonObject(with: bytes) as? [String: Int] == ["score": 16])
    }

    @Test func extensionSharesMetadataAndValidation() throws {
        let properties = ExtensionComputedFixture.sbjProperties
        #expect(properties.map(\.sourceName) == ["score", "baseDouble", "extensionModifier", "extensionTriple", "writable"])
        let modifier = try #require(properties.first { $0.sourceName == "extensionModifier" })
        #expect(modifier.info?.title == "Extension Modifier")
        #expect(modifier.constraints == [.integerRules(.init(range: 0...10))])
        var instance = ExtensionComputedFixture()
        #expect(modifier.value(in: instance) as? Int == 3)
        let writable = try #require(properties.first { $0.sourceName == "writable" }?.mutableProperty())
        #expect(writable.setValue(20, in: &instance))
        #expect(instance.score == 20)
        #expect(modifier.value(in: instance) as? Int == 5)
        instance.score = 100
        #expect(throws: SBJValidationError.self) { try instance.invariant(at: .root) }
        #expect(modifier.validationError(in: instance) != nil)
    }

    @Test func extensionDoesNotAlterEncoding() throws {
        let model = try JSONDecoder().decode(ExtensionComputedFixture.self, from: Data(#"{"score":22}"#.utf8))
        #expect(model.extensionModifier == 6)
        #expect(try JSONSerialization.jsonObject(with: JSONEncoder().encode(model)) as? [String: Int] == ["score": 22])
    }
}
