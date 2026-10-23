import Foundation
import SBJLocalization

/// Semantic imagery used by attachment UI and attachment help.
public enum SBJAttachmentSymbology: SBJSymbolSet {
    public static let all: [String: SBJSymbol] = [
        "attachments": .system("paperclip"),
        "previewAttachment": .system("doc.text.magnifyingglass"),
    ]

}
