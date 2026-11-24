import SBJLocalization

/// Structured editing, field-state, and navigation symbols.
public enum SBJStructuredEditorSymbology: SBJSymbolSet {
    public static let all: [String: SBJSymbol] = [
        "issues": .system("exclamationmark.circle.fill"),
        "clearOptional": .system("xmark.circle"),
        "setOptional": .system("circle.dashed"),
        "regenerate": .system("arrow.clockwise.circle"),
        "changed": .system("pencil"),
        "empty": .system("rectangle.dashed"),
        "formEditor": .system("rectangle.and.pencil.and.ellipsis"),
        "navigateToProperty": .system("chevron.right"),
    ]
}


/// Shared structured-editor actions and states. These definitions supply both UI
/// accessibility metadata and complete help entries; descriptions are not
/// repeated in the help HTML.
public enum SBJStructuredEditorNomenclature: SBJNomenclatureSet {
    public static let changed = SBJNomenclature(title: "Changed", summary: "Value differs from the original", details: "Marks a value changed since the editor opened.", symbol: SBJStructuredEditorSymbology.changed)
    public static let empty = SBJNomenclature(title: "Empty", summary: "No content", details: "Indicates a field with no content.", symbol: SBJStructuredEditorSymbology.empty)
    public static let setOptional = SBJNomenclature(title: "Set Optional Value", summary: "Creates a value and moves focus into the new field", details: "Creates and sets an optional value so it can be edited.", symbol: SBJStructuredEditorSymbology.setOptional)
    public static let clearOptional = SBJNomenclature(title: "Clear Optional Value", summary: "Removes the current optional value", details: "Clears the optional value and returns the field to its unset state.", symbol: SBJStructuredEditorSymbology.clearOptional)
    public static let checkIssues = SBJNomenclature(title: "Check Issues", details: "Checks the structure for issues and opens the issue list.", symbol: SBJStructuredEditorSymbology.issues)
    public static let issues = SBJNomenclature(title: "Issues", details: "Appears when the editor finds issues. Opens the issue list and checks the structure again; the button is hidden when there are no reported issues.", symbol: SBJStructuredEditorSymbology.issues)
    public static let navigateToProperty = SBJNomenclature(title: "Go to Field", summary: "Closes the issue viewer and reveals this property in the editor", details: "Closes the issue list, expands groups containing the selected field, and scrolls to it.", symbol: SBJStructuredEditorSymbology.navigateToProperty)
    public static let removeConfirmed = SBJNomenclature(title: "Remove Item", summary: "Asks for confirmation before removing this item", details: "Requests confirmation before removing the selected item from its collection.", symbol: SBJSymbology.remove)
    public static let regenerate = SBJNomenclature(title: "Generate New Value", details: "Generates a new identifier for the field.", symbol: SBJStructuredEditorSymbology.regenerate)

    public static let searchChanged = SBJNomenclature(title: "Changed", summary: "Shows only values changed since the editor opened", details: "Shows only values changed since the editor opened. Can be combined with other filters and text search.", symbol: SBJStructuredEditorSymbology.changed)
    public static let searchEmpty = SBJNomenclature(title: "Empty", summary: "Shows only values with no content", details: "Shows only values with no content. Can be combined with other filters and text search.", symbol: SBJStructuredEditorSymbology.empty)

    public static let all: [String: SBJNomenclature] = [
        "editor.changed": changed,
        "editor.empty": empty,
        "editor.set-optional": setOptional,
        "editor.clear-optional": clearOptional,
        "editor.information": .init(title: "Field Information", details: "Opens a description of the field and the value to enter.", symbol: SBJSymbology.information),
        "editor.expand": .init(title: "Expand Group", details: "Opens a collapsed group.", symbol: SBJSymbology.disclosureClosed),
        "editor.collapse": .init(title: "Collapse Group", details: "Closes an expanded group.", symbol: SBJSymbology.disclosureOpened),
        "editor.add-item": .init(title: "Add Item", details: "Adds an item to the collection.", symbol: SBJSymbology.add),
        "editor.remove-item": .init(title: "Remove Item", details: "Removes an item from the collection.", symbol: SBJSymbology.remove),
        "editor.move-up": .init(title: "Move Up", details: "Moves an item up one position.", symbol: SBJSymbology.moveUp),
        "editor.move-down": .init(title: "Move Down", details: "Moves an item down one position.", symbol: SBJSymbology.moveDown),
        "editor.move-first": .init(title: "Move to Beginning", details: "Moves an item to the beginning of the collection.", symbol: SBJSymbology.moveToFirst),
        "editor.move-last": .init(title: "Move to End", details: "Moves an item to the end of the collection.", symbol: SBJSymbology.moveToLast),
        "editor.issues": issues,
        "editor.check-issues": checkIssues,
        "editor.navigate-to-property": navigateToProperty,
        "editor.regenerate": regenerate,
        "editor.remove-confirmed": removeConfirmed,
        "editor.search-changed": searchChanged,
        "editor.search-empty": searchEmpty,
        "editor.adjust-number": .init(title: "Adjust Number", summary: "Increase or decrease the numeric value", details: "Use the stepper to adjust the field value."),
        "editor.first-unit-value": .init(title: "First Value", summary: "Edit the first quantity", details: "Sets the first quantity in the unit value."),
        "editor.second-unit-value": .init(title: "Second Value", summary: "Edit the optional second quantity", details: "Sets the second quantity in the unit value."),
        "editor.add-second-unit-value": .init(title: "Add Second Value", details: "Adds a second quantity to this unit value.", symbol: .system("plus.circle")),
        "editor.remove-second-unit-value": .init(title: "Remove Second Value", details: "Removes the second quantity from this unit value.", symbol: .system("minus.circle")),
    ]
}

import SBJStructuredReport
import SBJHelp

public extension SBJHelpConfiguration {
	static var structuredEditorHelp: Self {
		var configuration = SBJHelpConfiguration.standard
		configuration.addSymbolSet(SBJStructuredEditorSymbology.self)
        configuration.addNomenclatureSet(SBJStructuredEditorNomenclature.self)
        configuration.addNomenclatureSet(SBJStructuredReportNomenclature.self)
        configuration.addSymbolSet(SBJStructuredReportSymbology.self)
		return configuration
	}
}
