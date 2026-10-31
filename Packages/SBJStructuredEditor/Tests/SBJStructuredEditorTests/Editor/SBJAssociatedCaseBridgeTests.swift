import Foundation
import Testing
import SBJDataDefinition
@testable import SBJStructuredEditor

@SBJStructure
private enum BridgeSample: Codable {
    case plain
    case adjusted(amount: Int, enabled: Bool)
}

@MainActor
struct SBJAssociatedCaseBridgeTests {
    @Test func structuralEnumMetadataAdaptsToEditorCaseDescriptors() {
        let cases = BridgeSample.sbjStructuralEditorCases
        #expect(cases.map(\.name) == ["Plain", "Adjusted"])
        #expect(cases[1].associatedValues.map(\.name) == ["Amount", "Enabled"])
        #expect(cases[1].matches(.adjusted(amount: 2, enabled: true)))
        #expect(!cases[1].matches(.plain))
        #expect(cases[0].makeDefaultValue() != nil)
    }

    @Test func structuralEnumTraversesWithoutEditorMacroConformance() {
        let value = BridgeSample.adjusted(amount: 3, enabled: true)
        let nodes = SBJEditorValueTraversal.children(of: value, context: .root)
        #expect(nodes.count == 2)
        #expect(nodes.map(\.name) == ["Amount", "Enabled"])
    }
}
