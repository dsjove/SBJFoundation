import Foundation
import Testing
import SBJStructure
@testable import SBJStructuredReport

@SBJStructure
private struct EnhancedConstraintReportFixture {
    @SBJInteger(min: 1, max: 20) var level: Int = 10
    @SBJNumber(max: 10.0) var limit: Double = 5
    @SBJString(allowedValues: ["Small", "Large"], pattern: "[A-Za-z]+") var size: String = "Small"
    @SBJUnitValue(min: 2) var mass: UnitValue<MassUnit> = .init(3, unit: .gram)
    @SBJDictionary(key: [SBJStringRules(allowedValues: ["strength"])], value: [SBJIntegerRules(min: 1, max: 20)])
    var scores: [String: Int] = ["strength": 10]
}

@Test func reportIncludesEnhancedConstraintDescriptions() throws {
    let root = try #require(SBJDefinitionCatalog(EnhancedConstraintReportFixture.self).types.first {
        ObjectIdentifier($0.swiftType) == ObjectIdentifier(EnhancedConstraintReportFixture.self)
    })
    guard case .structure(let fields) = root.content else { Issue.record("Expected structure definition"); return }
    func descriptions(_ name: String) -> String {
        fields.first { $0.swiftIdentifier == name }?.constraints.map(\.description).joined(separator: " | ") ?? ""
    }
    let level = try #require(fields.first { $0.swiftIdentifier == "level" })
    #expect(level.constraints == [.integerRules(.init(min: 1, max: 20))])
    #expect(descriptions("level").contains("1"))
    #expect(descriptions("level").contains("20"))
    #expect(descriptions("limit").contains("Maximum"))
    #expect(descriptions("size").contains("Allowed values: Small, Large"))
    #expect(descriptions("size").contains("Pattern: [A-Za-z]+"))
    #expect(descriptions("mass").contains("Measurement minimum"))
    #expect(descriptions("scores").contains("Dictionary key"))
    #expect(descriptions("scores").contains("strength"))
    #expect(descriptions("scores").contains("Dictionary value"))
}
