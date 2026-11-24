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



/// Shared nomenclature used by the UI and help. The UI and help consume these same nomenclature definitions.
public enum SBJHelpNomenclature: SBJNomenclatureSet {
    public static let all: [String: SBJNomenclature] = [
        "help.ui.help": .init(title: "Help", symbol: SBJHelpSymbology.help),
        "help.ui.about": .init(title: "About", symbol: SBJHelpSymbology.about),
        "help.ui.help-unavailable": .init(title: "Help Unavailable", symbol: SBJHelpSymbology.helpUnavailable),
        "help.ui.unsupported-help": .init(title: "Unsupported Help Format", symbol: SBJHelpSymbology.unsupportedHelp),
        "help.ui.scroll-down": .init(title: "Scroll down one page", details: "Moves the help document down one page.", symbol: SBJHelpSymbology.scrollPageDown),
        "help.ui.scroll-top": .init(title: "Scroll to top", details: "Returns to the beginning of the help document.", symbol: SBJHelpSymbology.scrollToTop),
    ]
}
