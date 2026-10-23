import Foundation
import SBJFileResources
import SBJLocalization
import SBJUIVocabulary
import SBJHelp

/// Semantic imagery used by unit controls and unit-conversion help.
public enum SBJUnitConversionSymbology {
    public static let all: [String: SBJSymbol] = [
        "resetValue": .system("1.square"),
        "swapUnits": .system("arrow.left.arrow.right"),
    ]

    private static func image(_ name: String) -> SBJSymbol {
        guard let reference = all[name] else {
            preconditionFailure("Unknown unit semantic image: \(name)")
        }
        return reference
    }

    public static let resetValue = image("resetValue")
    public static let swapUnits = image("swapUnits")

    public static var unitConversionHelp: SBJBundledContentReference {
        .help("Unit Conversion", bundle: .module)
    }

    public static var helpConfiguration: SBJHelpConfiguration {
        var configuration = SBJHelpConfiguration.standard
        configuration.semanticImages = SBJSymbology.vocabulary(adding: all)
        return configuration
    }
}
