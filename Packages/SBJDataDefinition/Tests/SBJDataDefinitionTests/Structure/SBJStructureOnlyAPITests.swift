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
        XCTAssertEqual(DataOnlyModel.sbjMutableProperties[0].structuralMetadata?.sourceName, "value")
        XCTAssertEqual(DataOnlyModel().value, 3)
    }
}

// Models may accept optional arguments for nonoptional stored values so their
// initializer can substitute domain defaults. Source export must still select
// that initializer instead of a conversion-oriented convenience overload.
@SBJStructure
private struct OptionalInputReconstructionModel: Codable {
    var name: String
    var margin: Double

    init(name: String = "", margin: Double? = nil) {
        self.name = name
        self.margin = margin ?? 12
    }

    init(name: String = "", margin: String) {
        self.name = name
        self.margin = Double(margin) ?? 12
    }
}

final class SBJOptionalInputReconstructionTests: XCTestCase {
    func testOptionalInitializerArgumentsReconstructStoredValues() {
        let parameters = OptionalInputReconstructionModel.sbjSwiftInitializerParameters
        XCTAssertEqual(parameters.map(\.propertyName), ["name", "margin"])
        XCTAssertEqual(parameters.map(\.label), ["name", "margin"])

        let output = SBJSwiftEncoder().encode(
            OptionalInputReconstructionModel(name: "Custom", margin: 24), named: "layout"
        )
        XCTAssertTrue(output.contains("OptionalInputReconstructionModel("))
        XCTAssertTrue(output.contains("margin: 24"))
        XCTAssertFalse(output.contains("JSONDecoder"))
    }
}
