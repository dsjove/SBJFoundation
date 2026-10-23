import Foundation
import SBJFileResources
import SBJLocalization
import SBJUIVocabulary
import SBJHelp

/// Semantic imagery used by unit controls and unit-conversion help.
public enum SBJUnitConversionSymbology: SBJSymbolSet {
    public static let all: [String: SBJSymbol] = [
        "resetValue": .system("1.square"),
        "swapUnits": .system("arrow.left.arrow.right"),
    ]

    public static var unitConversionHelp: SBJBundledContentReference {
        .help("Unit Conversion", bundle: .module)
    }

    public static var helpConfiguration: SBJHelpConfiguration {
        var configuration = SBJHelpConfiguration.standard
        configuration.addSymbolSet(Self.self)
        return configuration
    }
}
