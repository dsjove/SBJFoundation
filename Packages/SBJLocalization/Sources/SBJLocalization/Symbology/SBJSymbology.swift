import Foundation

/// Vendor/application-level semantic localization: maps UI meaning to a bundled or system symbol.
///
/// `all` is the single source of truth for app/vendor UI symbols and HTML help (`UI_<name>\\`).
/// The typed properties below are only compile-time conveniences for ordinary Swift call sites;
/// they do not repeat or redefine the image mapping.
public enum SBJSymbology {
    public static let all: [String: SBJSymbol] = [
        "add": .system("plus.circle"),
        "remove": .system("minus.circle"),
        "apply": .system("checkmark.circle"),
        "selected": .system("checkmark"),
        "originalSelection": .system("circle.fill"),
        "checked": .system("checkmark.square.fill"),
        "unchecked": .system("square"),
        "clearOptional": .system("xmark.circle"),
        "setOptional": .system("circle.dashed"),
        "regenerate": .system("arrow.clockwise.circle"),
        "information": .system("info.circle"),
        "issues": .system("exclamationmark.circle.fill"),
        "moveUp": .system("arrow.up.circle"),
        "moveDown": .system("arrow.down.circle"),
        "moveToFirst": .system("arrow.up.to.line"),
        "moveToLast": .system("arrow.down.to.line"),
        "delete": .system("trash"),
        "restore": .system("arrow.uturn.backward.circle"),
        "changed": .system("pencil"),
        "empty": .system("rectangle.dashed"),
        "edit": .system("square.and.pencil"),
        "formEditor": .system("rectangle.and.pencil.and.ellipsis"),
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
        "navigateToProperty": .system("chevron.right"),
        "disclosureOpened": .system("chevron.down"),
        "disclosureClosed": .system("chevron.right"),
        "close": .system("xmark.circle"),
        "previous": .system("arrow.left.circle"),
        "next": .system("arrow.right.circle"),
        "play": .system("play.circle"),
        "pause": .system("pause.circle"),
    ]

    private static func image(_ name: String) -> SBJSymbol {
        guard let reference = all[name] else {
            preconditionFailure("Unknown standard semantic image: \\(name)")
        }
        return reference
    }

    public static let add = image("add")
    public static let remove = image("remove")
    public static let apply = image("apply")
    public static let selected = image("selected")
    public static let originalSelection = image("originalSelection")
    public static let checked = image("checked")
    public static let unchecked = image("unchecked")
    public static let clearOptional = image("clearOptional")
    public static let setOptional = image("setOptional")
    public static let regenerate = image("regenerate")
    public static let information = image("information")
    public static let issues = image("issues")
    public static let moveUp = image("moveUp")
    public static let moveDown = image("moveDown")
    public static let moveToFirst = image("moveToFirst")
    public static let moveToLast = image("moveToLast")
    public static let delete = image("delete")
    public static let restore = image("restore")
    public static let changed = image("changed")
    public static let empty = image("empty")
    public static let edit = image("edit")
    public static let formEditor = image("formEditor")
    public static let share = image("share")
    public static let link = image("link")
    public static let duplicate = image("duplicate")
    public static let lock = image("lock")
    public static let unlock = image("unlock")
    public static let more = image("more")
    public static let sections = image("sections")
    public static let theme = image("theme")
    public static let pageLayout = image("pageLayout")
    public static let documentSettings = image("documentSettings")
    public static let importDocument = image("importDocument")
    public static let exportDocument = image("exportDocument")
    public static let showInFolder = image("showInFolder")
    public static let swiftSource = image("swiftSource")
    public static let open = image("open")
    public static let unavailableLink = image("unavailableLink")
    public static let help = image("help")
    public static let about = image("about")
    public static let dismiss = image("dismiss")
    public static let helpUnavailable = image("helpUnavailable")
    public static let unsupportedHelp = image("unsupportedHelp")
    public static let scrollPageDown = image("scrollPageDown")
    public static let scrollToTop = image("scrollToTop")
    public static let navigateToProperty = image("navigateToProperty")
    public static let disclosureOpened = image("disclosureOpened")
    public static let disclosureClosed = image("disclosureClosed")
    public static let close = image("close")
    public static let previous = image("previous")
    public static let next = image("next")
    public static let play = image("play")
    public static let pause = image("pause")

    /// Returns the standard Foundation vocabulary merged with application-specific semantics.
    ///
    /// Application values win on duplicate keys so an app can deliberately customize a shared
    /// semantic image without introducing mutable global registration or initialization ordering.
    public static func vocabulary(adding additions: [String: SBJSymbol]) -> [String: SBJSymbol] {
        all.merging(additions) { _, application in application }
    }

    public static func disclosure(expanded: Bool) -> SBJSymbol {
        expanded ? disclosureOpened : disclosureClosed
    }
}
