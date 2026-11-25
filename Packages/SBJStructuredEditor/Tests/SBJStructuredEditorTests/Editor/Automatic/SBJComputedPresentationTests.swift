import Foundation
import Testing
@testable import SBJStructuredEditor
import SBJStructure

@SBJStructure
private struct EditorComputedFixture: Codable {
    var score: Int = 14
    var modifier: Int { (score - 10) / 2 }
    @SBJFieldPresentation(exclude: true)
    var hiddenResult: Int { score * 2 }
}

struct SBJComputedPresentationTests {
    @MainActor
    @Test func computedFieldIsReadOnly() {
        let fields = SBJStructuralFieldProjection.fields(of: EditorComputedFixture.self, showsReadOnlyProperties: true)
        let visible = fields.filter { $0.name == "Modifier" }
        #expect(visible.count == 1)
        #expect(visible.first?.metadata.access == .readOnly)
        #expect(fields.allSatisfy { $0.name != "hiddenResult" })
        #expect(fields.count == 2)
    }
}

@SBJStructure
private struct ExtensionEditorFixture: Codable {
    var score: Int = 18
}

@SBJStructureExtension
extension ExtensionEditorFixture {
    var modifier: Int { (score - 10) / 2 }

    @SBJFieldPresentation(exclude: true)
    var notPresented: Int { score * 2 }

    static let modifierNomenclature = SBJNomenclature(title: "Modifier")
}

struct SBJExtensionComputedPresentationTests {
    @MainActor
    @Test func extensionComputedAppearsReadOnlyUnlessExcluded() {
        #expect(SBJStructuralFieldProjection.fields(of: ExtensionEditorFixture.self).map(\.name) == ["Score"])
        let fields = SBJStructuralFieldProjection.fields(of: ExtensionEditorFixture.self, showsReadOnlyProperties: true)
        #expect(fields.filter { $0.name == "Modifier" }.count == 1)
        #expect(fields.first { $0.name == "Modifier" }?.metadata.access == .readOnly)
        #expect(fields.allSatisfy { $0.name != "Not Presented" })
        #expect(fields.count == 2)
    }
}

@SBJStructure
private struct MixedEditorComputedFixture: Codable {
    var base: Int = 10
    var primaryVisible: Int { base + 1 }
}

@SBJStructureExtension
extension MixedEditorComputedFixture {
    var extensionVisible: Int { base + 2 }
    @SBJFieldPresentation(exclude: true)
    var semanticOnly: Int { base + 3 }
    var unannotated: Int { base + 4 }
}

struct SBJCombinedComputedPresentationTests {
    @MainActor
    @Test func primaryAndExtensionComputedPropertiesShareVisibility() {
        let fields = SBJStructuralFieldProjection.fields(of: MixedEditorComputedFixture.self, showsReadOnlyProperties: true)
        #expect(fields.count == 4) // Stored base plus three visible computed fields.
        let primary = fields.first { $0.name == "Primary Visible" }
        let contributed = fields.first { $0.name == "Extension Visible" }
        #expect(primary != nil)
        #expect(contributed != nil)
        #expect(primary?.metadata.access == .readOnly)
        #expect(contributed?.metadata.access == .readOnly)
        #expect(fields.allSatisfy { $0.name != "Semantic Only" })
        #expect(fields.contains { $0.name == "Unannotated" })
    }
}

@SBJStructure
private struct ReadOnlyNestedFixture {
    var visible: String = "displayed"
    private var secret: String = "hidden-secret"
    @SBJFieldPresentation(exclude: true) var hidden: String = "hidden-field"
}

@SBJStructure
private struct ReadOnlyParentFixture {
    let nested: ReadOnlyNestedFixture = .init()
    private(set) var restricted: Int = 3
    @SBJInteger(min: 0) var invalidComputed: Int { -1 }
}

extension SBJComputedPresentationTests {
    @MainActor
    @Test func readonlyFieldsKeepMetadataAndDoNotExposePrivateState() {
        let root = ReadOnlyParentFixture()
        #expect(SBJStructuralFieldProjection.fields(of: ReadOnlyParentFixture.self).isEmpty)
        let fields = SBJStructuralFieldProjection.fields(of: ReadOnlyParentFixture.self, showsReadOnlyProperties: true)
        #expect(fields.allSatisfy { $0.metadata.access == .readOnly })
        #expect(fields.allSatisfy { $0.metadata.mutableProperty() == nil })
        #expect(fields.last?.metadata.validationError(in: root) != nil)
        let description = SBJEditorReadOnlyValue.text(root.nested)
        #expect(description.contains("displayed"))
        #expect(!description.contains("hidden-secret"))
        #expect(!description.contains("hidden-field"))
    }
}
