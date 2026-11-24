import Foundation
import Testing
@testable import SBJStructuredEditor
import SBJStructure

@SBJStructure
private struct EditorComputedFixture: Codable {
    var score: Int = 14
    @SBJComputed(showInEditor: true)
    var modifier: Int { (score - 10) / 2 }
    @SBJComputed
    var hiddenResult: Int { score * 2 }
}

struct SBJComputedPresentationTests {
    @MainActor
    @Test func explicitlyPresentedComputedFieldIsReadOnly() {
        let fields = SBJStructuralFieldProjection.fields(of: EditorComputedFixture.self)
        let visible = fields.filter { $0.name == "Modifier" }
        #expect(visible.count == 1)
        #expect(visible.first?.editableField.participatesInStructuralValidation == false)
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
    @SBJComputed(showInEditor: true)
    var modifier: Int { (score - 10) / 2 }

    @SBJComputed
    var notPresented: Int { score * 2 }

    static let modifierNomenclature = SBJNomenclature(title: "Modifier")
}

struct SBJExtensionComputedPresentationTests {
    @MainActor
    @Test func extensionComputedAppearsReadOnlyOnlyWhenOptedIn() {
        let fields = SBJStructuralFieldProjection.fields(of: ExtensionEditorFixture.self)
        #expect(fields.filter { $0.name == "Modifier" }.count == 1)
        #expect(fields.first { $0.name == "Modifier" }?.editableField.participatesInStructuralValidation == false)
        #expect(fields.allSatisfy { $0.name != "Not Presented" })
        #expect(fields.count == 2)
    }
}

@SBJStructure
private struct MixedEditorComputedFixture: Codable {
    var base: Int = 10
    @SBJComputed(showInEditor: true)
    var primaryVisible: Int { base + 1 }
}

@SBJStructureExtension
extension MixedEditorComputedFixture {
    @SBJComputed(showInEditor: true)
    var extensionVisible: Int { base + 2 }
    @SBJComputed
    var semanticOnly: Int { base + 3 }
    var unannotated: Int { base + 4 }
}

struct SBJCombinedComputedPresentationTests {
    @MainActor
    @Test func primaryAndExtensionPresentationCombineWithoutExposingOtherComputedValues() {
        let fields = SBJStructuralFieldProjection.fields(of: MixedEditorComputedFixture.self)
        #expect(fields.count == 3) // Stored base plus two explicitly presented computed fields.
        let primary = fields.first { $0.name == "Primary Visible" }
        let contributed = fields.first { $0.name == "Extension Visible" }
        #expect(primary != nil)
        #expect(contributed != nil)
        #expect(primary?.editableField.participatesInStructuralValidation == false)
        #expect(contributed?.editableField.participatesInStructuralValidation == false)
        #expect(fields.allSatisfy { $0.name != "Semantic Only" && $0.name != "Unannotated" })
    }
}
