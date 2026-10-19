import SBJHelp
import Foundation
import SBJDataDefinition
import SBJLocalization

/// Semantic imagery used by attachment UI and attachment help.
public enum SBJAttachmentSymbology {
    public static let all: [String: SBJSymbol] = [
        "attachments": .system("paperclip"),
        "previewAttachment": .system("doc.text.magnifyingglass"),
    ]

    private static func image(_ name: String) -> SBJSymbol {
        guard let reference = all[name] else {
            preconditionFailure("Unknown attachment semantic image: \(name)")
        }
        return reference
    }

    public static let attachments = image("attachments")
    public static let previewAttachment = image("previewAttachment")

    public static var helpConfiguration: SBJHelpConfiguration {
        var configuration = SBJHelpConfiguration.foundation
        configuration.semanticImages = SBJSymbology.vocabulary(adding: all)
        return configuration
    }
}
