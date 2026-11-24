import Foundation

/// Vendor/application-level semantic localization: maps UI meaning to a bundled or system symbol.
///
/// `all` is the single source of truth for app/vendor UI symbols and HTML help (`UI_<name>\\`).
/// The typed properties below are only compile-time conveniences for ordinary Swift call sites;
/// they do not repeat or redefine the image mapping.
public enum SBJSymbology: SBJSymbolSet {
    public static let all: [String: SBJSymbol] = [
        "add": .system("plus.circle"),
        "remove": .system("minus.circle"),
        "apply": .system("checkmark.circle"),
        "selected": .system("checkmark"),
        "originalSelection": .system("circle.fill"),
        "checked": .system("checkmark.square.fill"),
        "unchecked": .system("square"),
        "information": .system("info.circle"),
        "moveUp": .system("arrow.up.circle"),
        "moveDown": .system("arrow.down.circle"),
        "moveToFirst": .system("arrow.up.to.line"),
        "moveToLast": .system("arrow.down.to.line"),
        "delete": .system("trash"),
        "restore": .system("arrow.uturn.backward.circle"),
        "edit": .system("square.and.pencil"),
        "share": .system("square.and.arrow.up"),
        "link": .system("link.circle"),
        "duplicate": .system("plus.square.on.square"),
        "more": .system("ellipsis.circle"),
        "open": .system("arrow.up.forward.app"),
        "unavailableLink": .system("xmark.circle.fill"),
        "dismiss": .system("checkmark.circle"),
        "disclosureOpened": .system("chevron.down"),
        "disclosureClosed": .system("chevron.right"),
        "close": .system("xmark.circle"),
        "previous": .system("arrow.left.circle"),
        "next": .system("arrow.right.circle"),
        "play": .system("play.circle"),
        "pause": .system("pause.circle"),
    ]

    public static func disclosure(expanded: Bool) -> SBJSymbol {
        expanded ? self.disclosureOpened : self.disclosureClosed
    }
}

/// Shared action nomenclature; applications can provide more specific contextual definitions.
public enum SBJCommonNomenclature: SBJNomenclatureSet {
    public static var all: [String: SBJNomenclature] { [
        "add": .init(title: "Add", symbol: SBJSymbology.add),
        "remove": .init(title: "Remove", symbol: SBJSymbology.remove),
        "apply": .init(title: "Apply", symbol: SBJSymbology.apply),
        "delete": .init(title: "Delete", symbol: SBJSymbology.delete),
        "edit": .init(title: "Edit", symbol: SBJSymbology.edit),
        "close": .init(title: "Close", symbol: SBJSymbology.close),
        "dismiss": .init(title: "Dismiss", symbol: SBJSymbology.dismiss),
        "moveUp": .init(title: "Move up", symbol: SBJSymbology.moveUp),
        "moveDown": .init(title: "Move down", symbol: SBJSymbology.moveDown),
        "moveToFirst": .init(title: "Move to first", symbol: SBJSymbology.moveToFirst),
        "moveToLast": .init(title: "Move to last", symbol: SBJSymbology.moveToLast),
        "information": .init(title: "Information", symbol: SBJSymbology.information),
        "open": .init(title: "Open", symbol: SBJSymbology.open),
        "editInSheet": .init(title: "Edit in sheet", symbol: SBJSymbology.edit),
        "expand": .init(title: "Expand", details: "Expands the selected group to display its contents.", symbol: SBJSymbology.disclosureClosed),
        "collapse": .init(title: "Collapse", details: "Collapses the selected group to hide its contents.", symbol: SBJSymbology.disclosureOpened),
        "expanded": .init(title: "Expanded", details: "The group is currently expanded."),
        "collapsed": .init(title: "Collapsed", details: "The group is currently collapsed."),
        "share": .init(title: "Share", details: "Open the system sharing options.", symbol: SBJSymbology.share),
        "search": .init(title: "Search", summary: "Filter results by entering search text."),
        "done": .init(title: "Done", details: "Finishes editing and closes this view."),
        "cancel": .init(title: "Cancel", details: "Dismisses the current action without applying it."),
    ] }
}

