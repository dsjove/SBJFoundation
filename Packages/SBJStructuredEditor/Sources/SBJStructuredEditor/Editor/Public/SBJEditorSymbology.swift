import SBJLocalization

/// Structured editing, field-state, and navigation symbols.
public enum SBJEditorSymbology: SBJSymbolSet {
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
