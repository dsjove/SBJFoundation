import SBJLocalization

/// Symbols that belong to the help presenter rather than shared application actions.
public enum SBJHelpSymbology: SBJSymbolSet {
    public static let all: [String: SBJSymbol] = [
        "help": .system("questionmark.circle"),
        "about": .system("info.circle"),
        "helpUnavailable": .system("questionmark.circle"),
        "unsupportedHelp": .system("doc.questionmark"),
        "scrollPageDown": .system("chevron.down"),
        "scrollToTop": .system("chevron.up.2"),
    ]
}

public extension SBJHelpSymbology {
    static var helpLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.help, title: "Help")
    }
    static var aboutLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.about, title: "About")
    }
    static var helpUnavailableLabel: SBJLabeledSymbol { SBJLabeledSymbol(symbol: self.helpUnavailable, title: "Help Unavailable") }
    static var unsupportedHelpLabel: SBJLabeledSymbol { SBJLabeledSymbol(symbol: self.unsupportedHelp, title: "Unsupported Help Format") }
}
