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

public extension SBJSymbology {
    static var addLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.add, title: "Add")
    }
    static var removeLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.remove, title: "Remove")
    }
    static var applyLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.apply, title: "Apply")
    }
    static var deleteLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.delete, title: "Delete")
    }
    static var editLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.edit, title: "Edit")
    }
    static var closeLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.close, title: "Close")
    }
    static var shareLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.share, title: "Share")
    }
}
