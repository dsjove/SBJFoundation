import Foundation
import SBJDataDefinition
import SBJHelp
import SBJUIVocabulary

/// Semantic imagery used by tag UI and tag help.
public enum SBJTagSymbology: SBJSymbolSet {
    public static let all: [String: SBJSymbol] = [
        "tags": .system("tag.fill"),
        "primaryTag": .system("star.fill"),
        "notPrimaryTag": .system("star"),
    ]

    public static var helpConfiguration: SBJHelpConfiguration {
        var configuration = SBJHelpConfiguration.standard
        configuration.addSymbolSet(Self.self)
        return configuration
    }
}
