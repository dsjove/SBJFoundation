import Foundation
import SBJLocalization

/// Semantic imagery used by attachment UI and attachment help.
public enum SBJAttachmentSymbology: SBJSymbolSet {
    public static let all: [String: SBJSymbol] = [
        "attachments": .system("paperclip"),
        "previewAttachment": .system("doc.text.magnifyingglass"),
    ]
}


/// Shared attachment-editor vocabulary. This is the source for visible labels,
/// accessible action names, and the help renderer's NOM tokens.
/// Attachment-specific IDs avoid conflating removal of an attachment with
/// deletion of an underlying file.
public enum SBJAttachmentNomenclature: SBJNomenclatureSet {
    public static let all: [String: SBJNomenclature] = [
        "ui.attachments.collection": .init(
            title: "Attachments",
            details: "Attachments associate files or embedded resources with the current item.",
            symbol: SBJAttachmentSymbology.attachments),
        "ui.attachments.add": .init(
            title: "Add Attachment",
            details: "Choose one or more files to attach to the current item.",
            symbol: SBJSymbology.add),
        "ui.attachments.rename": .init(
            title: "Rename Attachment",
            details: "Edit the attachment name directly; its filename extension is preserved.",
            symbol: SBJAttachmentSymbology.attachments),
        "ui.attachments.preview": .init(
            title: "Preview Attachment",
            details: "Preview a supported attachment without leaving the editor.",
            symbol: SBJAttachmentSymbology.previewAttachment),
        "ui.attachments.remove": .init(
            title: "Remove Attachment",
            details: "Detach the attachment from the current item. Whether its underlying file is deleted depends on how the item stores attachments.",
            symbol: SBJSymbology.remove),
    ]
}
