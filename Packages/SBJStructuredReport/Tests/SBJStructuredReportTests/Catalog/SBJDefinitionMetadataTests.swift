import Foundation
import Testing
import SBJStructure
@testable import SBJStructuredReport

@SBJStructure
private struct DefinitionMetadataFixture {
    @SBJInteger(range: 0...100)
    var hitPoints: Int = 30

    @SBJFieldPresentation(exclude: true)
    var secret: String = "hidden from editors"

    @SBJInteger(range: 0...200)
    var doubled: Int { hitPoints * 2 }

    var editableComputed: Int {
        get { hitPoints }
        set { hitPoints = newValue }
    }
    let immutable: Int = 1
    private var privateState = 0
    @SBJExclude var excludedState = 0
    var neverEvaluate: Int { fatalError("Report evaluated a getter") }

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
    #expect(!computed.constraints.isEmpty)
    #expect(computed.access == .readOnly)
    #expect(fields.first { $0.swiftIdentifier == "editableComputed" }?.access == .readWrite)
    #expect(fields.first { $0.swiftIdentifier == "immutable" }?.access == .readOnly)
    #expect(!fields.contains { ["privateState", "excludedState"].contains($0.swiftIdentifier) })
    #expect(fields.contains { $0.swiftIdentifier == "neverEvaluate" })
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

@SBJStructure
private struct CatalogLeaf: Hashable {
    var name: String = ""
}

@SBJStructure
private enum CatalogChoice {
    case none
    case item(CatalogLeaf)
}

@SBJStructure
private struct CatalogContainers {
    var items: [String: [CatalogLeaf?]] = [:]
    var choice: CatalogChoice = .none
    var leaves: Set<CatalogLeaf> = []
}

@Test func catalogDiscoversNestedTypesAndPayloadsWithoutInstances() throws {
    let catalog = SBJDefinitionCatalog(CatalogContainers.self)
    #expect(catalog.types.filter { $0.swiftType == CatalogLeaf.self }.count == 1)
    let choice = try #require(catalog.types.first { $0.swiftType == CatalogChoice.self })
    guard case .enumeration(let cases) = choice.content else {
        Issue.record("Expected enum definition")
        return
    }
    let item = try #require(cases.first { $0.swiftIdentifier == "item" })
    #expect(item.payloads.count == 1)
    #expect(item.payloads.first.map { ObjectIdentifier($0.declaredType) } == ObjectIdentifier(CatalogLeaf.self))
}
