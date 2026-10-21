import XCTest
@testable import SBJDataDefinition

@SBJStructure
private struct DataOnlyModel: Codable {
    var value: Int = 3
}

final class SBJStructureOnlyAPITests: XCTestCase {
    func testStructureGeneratesDataMetadata() {
        XCTAssertEqual(DataOnlyModel.sbjProperties.count, 1)
        XCTAssertEqual(DataOnlyModel.sbjMutableProperties.count, 1)
        XCTAssertEqual(DataOnlyModel().value, 3)
    }
}
