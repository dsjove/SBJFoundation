import Foundation
import Testing
import SBJStructure
@testable import SBJStructuredReport

@SBJStructure
private struct DefinitionMetadataFixture: Codable {
    @SBJInteger(range: 0...100)
    var hitPoints: Int = 30

    @SBJFieldPresentation(exclude: true)
    var secret: String = "hidden from editors"

    @SBJComputed
    var doubled: Int { hitPoints * 2 }

    static let hitPointsNomenclature = SBJNomenclature(
        title: "Hit Points", aliases: ["HP"]
    )
}

@Test func reportRetainsMetadataExcludedFromEditors() throws {
    let catalog = SBJDefinitionCatalog(DefinitionMetadataFixture.self)
    let definition = try #require(catalog.types.first {
        $0.swiftType == DefinitionMetadataFixture.self
    })
    guard case .structure(let fields) = definition.content else {
        Issue.record("Expected structure definition")
        return
    }
    let secret = try #require(fields.first { $0.swiftIdentifier == "secret" })
    #expect(!secret.visibleToEditor)
    #expect(!secret.visibleToSemanticEditor)
    let health = try #require(fields.first { $0.swiftIdentifier == "hitPoints" })
    #expect(health.info?.aliases.contains("HP") == true)
    #expect(!health.constraints.isEmpty)
}

@Test func reportIncludesComputedWithoutEvaluatingInstance() throws {
    let catalog = SBJDefinitionCatalog(DefinitionMetadataFixture.self)
    let definition = try #require(catalog.types.first {
        $0.swiftType == DefinitionMetadataFixture.self
    })
    guard case .structure(let fields) = definition.content else {
        Issue.record("Expected structure definition")
        return
    }
    let computed = try #require(fields.first { $0.swiftIdentifier == "doubled" })
    #expect(computed.isComputed)
    #expect(computed.constraints.isEmpty)
    #expect(computed.hints.isEmpty)
}

@Test func catalogBuilderDeduplicatesRegisteredTypes() {
    var builder = SBJDefinitionCatalog.Builder()
    builder.add(DefinitionMetadataFixture.self)
    builder.add(DefinitionMetadataFixture.self)
    let catalog = builder.build()
    #expect(catalog.types.filter { $0.swiftType == DefinitionMetadataFixture.self }.count == 1)
}

@Test func catalogSortingPreservesDeclarationMetadata() throws {
    let original = SBJDefinitionCatalog(DefinitionMetadataFixture.self)
    let alphabetical = original.sorted(using: .init(propertySort: .alphabetical))
    let declaration = alphabetical.sorted(using: .init(propertySort: .declaration))
    let root = try #require(declaration.types.first { $0.swiftType == DefinitionMetadataFixture.self })
    guard case .structure(let fields) = root.content else {
        Issue.record("Expected structure definition")
        return
    }
    #expect(fields.map(\.declarationIndex) == fields.map(\.declarationIndex).sorted())
    #expect(fields.contains { $0.swiftIdentifier == "doubled" && $0.isComputed })
}
