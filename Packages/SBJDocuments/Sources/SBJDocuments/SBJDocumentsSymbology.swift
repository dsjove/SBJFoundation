import SBJLocalization

/// Symbols for document ownership and document-related actions.
public enum SBJDocumentsSymbology: SBJSymbolSet {
    public static let all: [String: SBJSymbol] = [
        "documentSettings": .system("doc.badge.gearshape"),
        "importDocument": .system("arrow.down.document"),
        "exportDocument": .system("arrow.up.document"),
        "showInFolder": .system("folder"),
        "swiftSource": .system("swift"),
    ]
}
