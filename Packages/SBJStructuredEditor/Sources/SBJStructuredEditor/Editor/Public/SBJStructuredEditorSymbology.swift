import SBJLocalization

/// Structured editing, field-state, and navigation symbols.
public enum SBJStructuredEditorSymbology: SBJSymbolSet {
    public static let all: [String: SBJSymbol] = [
        "clearOptional": .system("xmark.circle"),
        "setOptional": .system("circle.dashed"),
        "regenerate": .system("arrow.clockwise.circle"),
        "changed": .system("pencil"),
        "empty": .system("rectangle.dashed"),
        "formEditor": .system("rectangle.and.pencil.and.ellipsis"),
        "navigateToProperty": .system("chevron.right"),
    ]
}

import SBJHelp

public extension SBJHelpConfiguration {
	static var structuredEditorHelp: Self {
		var configuration = SBJHelpConfiguration.standard
		configuration.addSymbolSet(SBJStructuredEditorSymbology.self)
		return configuration
	}
}
