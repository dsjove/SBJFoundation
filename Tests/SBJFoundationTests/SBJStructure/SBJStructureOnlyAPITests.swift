import SBJUIVocabulary
import XCTest
import SBJDataDefinition
import SBJFoundation

@SBJStructure
private struct DataOnlyModel: Codable {
    var value: Int = 3
}

@SBJEditable
private struct EditableModel: Codable {
    var value: Int = 3
}

final class SBJStructureOnlyAPITests: XCTestCase {
    func testStructureGeneratesDataMetadata() {
        XCTAssertEqual(DataOnlyModel.sbjProperties.count, 1)
        XCTAssertEqual(DataOnlyModel.sbjMutableProperties.count, 1)
        XCTAssertEqual(DataOnlyModel().value, 3)
    }

    @MainActor
    func testEditableIncludesStructuralAndEditorMetadata() {
        XCTAssertEqual(EditableModel.sbjProperties.count, 1)
        XCTAssertEqual(EditableModel.sbjMutableProperties.count, 1)
        XCTAssertEqual(EditableModel.sbjEditorFields.count, 1)
    }
}
