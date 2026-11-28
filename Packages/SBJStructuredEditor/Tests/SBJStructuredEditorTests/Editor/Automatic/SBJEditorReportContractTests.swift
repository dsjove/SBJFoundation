#if !os(tvOS) && !os(watchOS)
import Testing
import SBJStructure
import SBJStructuredReport
@testable import SBJStructuredEditor

@SBJStructure
private struct EditorReportFixture {
    var name: String = "Example"
    @SBJFieldPresentation(exclude: true) var hidden: String = "report only"
    private var secret: String = "private"
    @SBJExclude var excluded: String = "excluded"
    @SBJInteger(min: 0) var computed: Int { 3 }
    let identifier: Int = 1
    var items: [String]? = nil
}

@SBJStructure
private enum EditorReportChoice {
    case automatic
    case adjusted(Int)
}

@SBJNomenclatureEnum
extension EditorReportChoice {
    static let adjustedNomenclature = SBJNomenclature(title: "Adjusted score")
}

@MainActor
struct SBJEditorReportContractTests {
    @Test func editorAndReportShareDefinitionAndVisibility() throws {
        let fields = SBJStructuralFieldProjection.fields(of: EditorReportFixture.self, traversalOptions: .all)
        let catalog = SBJDefinitionCatalog(EditorReportFixture.self)
        let definition = try #require(catalog.types.first { $0.swiftType == EditorReportFixture.self })
        guard case .structure(let properties) = definition.content else {
            Issue.record("Expected structure definition")
            return
        }
        #expect(properties.map(\.swiftIdentifier) == ["name", "hidden", "computed", "identifier", "items"])
        #expect(fields.map { $0.metadata.sourceName } == properties.filter { !$0.isPresentationExcluded }.map(\.swiftIdentifier))
        for field in fields {
            let property = try #require(properties.first { $0.swiftIdentifier == field.metadata.sourceName })
            #expect(property.access == field.metadata.access)
            #expect(property.storage == field.metadata.storage)
            #expect(ObjectIdentifier(property.declaredType) == ObjectIdentifier(field.metadata.valueType))
            #expect(property.isPresentationExcluded == field.metadata.isPresentationExcluded)
        }
        let allFields = SBJStructuralFieldProjection.fields(of: EditorReportFixture.self, traversalOptions: .definition)
        #expect(allFields.map { $0.metadata.sourceName } == properties.map(\.swiftIdentifier))
        let computed = try #require(properties.first { $0.swiftIdentifier == "computed" })
        #expect(!computed.constraints.isEmpty)
        #expect(computed.access == .readOnly)
    }

    @Test func optionalEnumCaseUsesSharedDiscovery() {
        let present: EditorReportChoice?? = .some(.some(.adjusted(4)))
        let absent: EditorReportChoice? = nil
        #expect(SBJEditorEnumCaseInformation.info(for: present as Any)?.sourceName == "adjusted")
        #expect(SBJEditorEnumCaseInformation.info(for: present as Any)?.title == "Adjusted score")
        #expect(SBJEditorEnumCaseInformation.info(for: absent as Any) == nil)
    }

    @Test func readOnlyOptionalSummaryDoesNotReflectStorage() {
        let missing: String? = nil
        let nested: String?? = .some(.some("present"))
        #expect(SBJEditorReadOnlyValue.text(missing as Any) == "—")
        #expect(SBJEditorReadOnlyValue.text(nested as Any) == "present")
        #expect(SBJEditorReadOnlyValue.text(EditorReportFixture()).contains("Example"))
        #expect(!SBJEditorReadOnlyValue.text(EditorReportFixture()).contains("report only"))
        #expect(!SBJEditorReadOnlyValue.text(EditorReportFixture()).contains("private"))
    }
}
#endif
