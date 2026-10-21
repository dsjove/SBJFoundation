import XCTest
import SBJStructuredEditor

@SBJEditable
private struct EditableModel: Codable {
    var value: Int = 3
}

final class SBJStructureOnlyAPITests: XCTestCase {
    @MainActor
    func testEditableIncludesStructuralAndEditorMetadata() {
        XCTAssertEqual(EditableModel.sbjProperties.count, 1)
        XCTAssertEqual(EditableModel.sbjMutableProperties.count, 1)
        XCTAssertEqual(EditableModel.sbjEditorFields.count, 1)
    }
}
