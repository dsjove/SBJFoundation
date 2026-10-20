import Testing
import SBJDataDefinition
@testable 
@Suite("Menu selection states")
struct SBJMenuSelectionPolicyTests {
    private let single = [SBJMenuChoice(id: 0, title: "Only")]

    @Test func zeroChoicesHasNoMenu() {
        #expect(!SBJMenuSelectionPolicy.showsMenu(selection: nil, choices: [], invalid: false))
    }

    @Test func oneMatchingChoiceIsStatic() {
        #expect(!SBJMenuSelectionPolicy.showsMenu(selection: 0, choices: single, invalid: false))
    }

    @Test func unmatchedSelectionIsInvalidAndAllowsRepair() {
        #expect(SBJMenuSelectionPolicy.isInvalid(selection: 2, choices: single, explicitInvalid: false))
        #expect(SBJMenuSelectionPolicy.showsMenu(selection: 2, choices: single, invalid: true))
    }

    @Test func editorCanFlagUnmatchedOptionalSelection() {
        #expect(SBJMenuSelectionPolicy.isInvalid(selection: nil, choices: single, explicitInvalid: true))
        #expect(SBJMenuSelectionPolicy.showsMenu(selection: nil, choices: single, invalid: true))
    }

    @Test func severalChoicesAreInteractive() {
        let choices = single + [SBJMenuChoice(id: 1, title: "Another")]
        #expect(SBJMenuSelectionPolicy.showsMenu(selection: 0, choices: choices, invalid: false))
    }

    @Test func disabledChoicesAreNotActionable() {
        let choices = [SBJMenuChoice(id: 0, title: "Disabled", isEnabled: false)]
        #expect(!SBJMenuSelectionPolicy.showsMenu(selection: 0, choices: choices, invalid: false))
    }
}
