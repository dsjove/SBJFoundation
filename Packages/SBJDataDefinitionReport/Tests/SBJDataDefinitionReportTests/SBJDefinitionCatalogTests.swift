import Testing
import SBJDataDefinition
@testable import SBJDataDefinitionReport

@SBJStructure
private struct ReportFixture: Codable {
    var last: Int
    let first: String
}

private enum ReportEnumFixture: String, Codable, SBJEnumCaseIdentifiable {
    case last, first
    static var sbjCaseNames: [String] { ["last", "first"] }
    var sbjCaseName: String { rawValue }
}

@SBJStructure
private enum ReportPayloadFixture: Codable {
    case plain
    case adjusted(value: Int, note: String?)
}

@Suite("Definition catalog")
struct SBJDefinitionCatalogTests {
    @Test func storedFieldsAndIdentifierArePreserved() {
        let catalog = SBJDefinitionCatalog(ReportFixture.self)
        #expect(catalog.types.count == 1)
        guard case .structure(let fields) = catalog.types[0].content else {
            Issue.record("Expected a structure"); return
        }
        #expect(fields.map(\.swiftIdentifier) == ["last", "first"])
        #expect(fields.allSatisfy(\.isStored))
        #expect(fields[1].typeName.contains("String"))
    }

    @Test func independentSortingAndDeduplication() {
        var builder = SBJDefinitionCatalog.Builder(options: .init(propertySort: .alphabetical, caseSort: .alphabetical))
        builder.add(ReportFixture.self)
        builder.add(ReportFixture.self)
        builder.add(ReportEnumFixture.self)
        let catalog = builder.build()
        #expect(catalog.types.count == 2)
        let fields = catalog.types.compactMap { item -> [SBJDefinitionProperty]? in
            guard case .structure(let result) = item.content else { return nil }
            return result
        }.first
        #expect(fields?.map(\.swiftIdentifier) == ["first", "last"])
        let cases = catalog.types.compactMap { item -> [SBJDefinitionCase]? in
            guard case .enumeration(let result) = item.content else { return nil }
            return result
        }.first
        #expect(cases?.map(\.swiftIdentifier) == ["first", "last"])
    }

    @Test func associatedPayloadsRetainTypesWithoutCreatingValues() {
        var builder = SBJDefinitionCatalog.Builder()
        builder.add(ReportPayloadFixture.self)
        let catalog = builder.build()
        guard case .enumeration(let cases) = catalog.types[0].content else {
            Issue.record("Expected enum"); return
        }
        #expect(cases.map(\.swiftIdentifier) == ["plain", "adjusted"])
        #expect(cases[0].payloads.isEmpty)
        #expect(cases[1].payloads.map(\.name) == ["Value", "Note"] ||
                cases[1].payloads.map(\.name) == ["value", "note"])
        #expect(cases[1].payloads[0].typeName.contains("Int"))
    }
}
