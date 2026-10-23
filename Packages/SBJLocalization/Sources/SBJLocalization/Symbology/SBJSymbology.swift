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
        "issues": .system("exclamationmark.circle.fill"),
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
        "lock": .system("lock"),
        "unlock": .system("lock.open"),
        "more": .system("ellipsis.circle"),
        "sections": .system("rectangle.grid.1x3"),
        "theme": .system("paintpalette"),
        "pageLayout": .system("inset.filled.rectangle.portrait"),
        "documentSettings": .system("doc.badge.gearshape"),
        "importDocument": .system("arrow.down.document"),
        "exportDocument": .system("arrow.up.document"),
        "showInFolder": .system("folder"),
        "swiftSource": .system("swift"),
        "open": .system("arrow.up.forward.app"),
        "unavailableLink": .system("xmark.circle.fill"),
        "help": .system("questionmark.circle"),
        "about": .system("info.circle"),
        "dismiss": .system("checkmark.circle"),
        "helpUnavailable": .system("questionmark.circle"),
        "unsupportedHelp": .system("doc.questionmark"),
        "scrollPageDown": .system("chevron.down"),
        "scrollToTop": .system("chevron.up.2"),
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
