import XCTest
@testable import SBJStructuredEditor

@SBJStructure
private struct EditableModel: Codable {
    var value: Int = 3
}

final class SBJStructureOnlyAPITests: XCTestCase {
    @MainActor
    func testStructuralProjectionUsesDataDefinitionMetadata() {
        XCTAssertEqual(SBJStructuralFieldProjection.fields(of: EditableModel.self).count, 1)
    }
}
