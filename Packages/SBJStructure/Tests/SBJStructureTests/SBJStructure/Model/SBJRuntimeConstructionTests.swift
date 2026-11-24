import Foundation
import Testing
@testable import SBJStructure

@SBJStructure
private struct RuntimeConstructMutable: Codable {
    var hitPoints: Int = 10
    var label: String = "Default"
}

@SBJStructureExtension
extension RuntimeConstructMutable {
    static let hitPointsNomenclature = SBJNomenclature(
        title: "Hit Points", aliases: ["HP"]
    )
}

@SBJStructure
private struct RuntimeConstructImmutable: Codable {
    let id: Int
    let name: String
}

@Test func runtimeConstructionUsesDefaultsAndMemberAliases() throws {
    let json = Data(#"{"HP": 23}"#.utf8)
    let result = try SBJRuntimeConstruction.construct(RuntimeConstructMutable.self, fromJSON: json)
    #expect(result.hitPoints == 23)
    #expect(result.label == "Default")
}

@Test func runtimeConstructionBuildsImmutableModelsThroughCodable() throws {
    let json = Data(#"{"id": 3, "name": "Created"}"#.utf8)
    let result = try SBJRuntimeConstruction.construct(RuntimeConstructImmutable.self, fromJSON: json)
    #expect(result.id == 3)
    #expect(result.name == "Created")
}

@Test func runtimeConstructionRejectsUnrecognizedAndDuplicateNames() throws {
    #expect(throws: SBJRuntimeConstruction.Failure.self) {
        _ = try SBJRuntimeConstruction.construct(
            RuntimeConstructMutable.self, fromJSON: Data(#"{"nonexistent": 1}"#.utf8)
        )
    }
    #expect(throws: SBJRuntimeConstruction.Failure.self) {
        _ = try SBJRuntimeConstruction.construct(
            RuntimeConstructMutable.self, fromJSON: Data(#"{"HP": 1, "hitPoints": 2}"#.utf8)
        )
    }
}

@Test func runtimeConstructionRejectsMissingRequiredImmutableMembers() throws {
    #expect(throws: DecodingError.self) {
        _ = try SBJRuntimeConstruction.construct(
            RuntimeConstructImmutable.self, fromJSON: Data(#"{"id": 3}"#.utf8)
        )
    }
}

@Test func runtimeConstructionWorksThroughCollectionElementParser() throws {
    let value = try [RuntimeConstructMutable]().sbjParseCollectionScalar(
        #"{"HP": 18}"#, role: .element
    )
    let constructed = try #require(value as? RuntimeConstructMutable)
    #expect(constructed.hitPoints == 18)
    #expect(constructed.label == "Default")
}

@Test func runtimeConstructionRejectsInvalidFieldValue() throws {
    #expect(throws: SBJRuntimeConstruction.Failure.self) {
        _ = try SBJRuntimeConstruction.construct(
            RuntimeConstructMutable.self, fromJSON: Data(#"{"hitPoints": "not an integer"}"#.utf8)
        )
    }
}
