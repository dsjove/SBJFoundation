import SBJLocalization

/// Symbols owned by layout and PDF presentation features.
public enum SBJLayoutSymbology: SBJSymbolSet {
    public static let all: [String: SBJSymbol] = [
        "theme": .system("paintpalette"),
        "pageLayout": .system("inset.filled.rectangle.portrait"),
        "firstPage": .system("backward.end"),
        "previousPage": .system("chevron.left"),
        "nextPage": .system("chevron.right"),
        "lastPage": .system("forward.end"),
        "searchPDF": .system("magnifyingglass"),
        "previousSearchMatch": .system("chevron.up"),
        "nextSearchMatch": .system("chevron.down"),
        "closeSearch": .system("xmark"),
    ]
}



/// Shared nomenclature used by the UI and help. The UI and help consume these same nomenclature definitions.
public enum SBJLayoutNomenclature: SBJNomenclatureSet {
    public static let all: [String: SBJNomenclature] = [
        "layout.ui.page-layout": .init(title: "Page Layout", symbol: SBJLayoutSymbology.pageLayout, accessibilityLabel: "Edit page layout", accessibilityHint: "Configure page layout"),
        "layout.ui.first-page": .init(title: "First Page", symbol: SBJLayoutSymbology.firstPage, accessibilityLabel: "Go to first page"),
        "layout.ui.previous-page": .init(title: "Previous Page", symbol: SBJLayoutSymbology.previousPage, accessibilityLabel: "Go to previous page"),
        "layout.ui.next-page": .init(title: "Next Page", symbol: SBJLayoutSymbology.nextPage, accessibilityLabel: "Go to next page"),
        "layout.ui.last-page": .init(title: "Last Page", symbol: SBJLayoutSymbology.lastPage, accessibilityLabel: "Go to last page"),
        "layout.ui.search-p-d-f": .init(title: "Search PDF", symbol: SBJLayoutSymbology.searchPDF, accessibilityLabel: "Search PDF"),
        "layout.ui.previous-search-match": .init(title: "Previous Match", symbol: SBJLayoutSymbology.previousSearchMatch, accessibilityLabel: "Go to previous search result"),
        "layout.ui.next-search-match": .init(title: "Next Match", symbol: SBJLayoutSymbology.nextSearchMatch, accessibilityLabel: "Go to next search result"),
        "layout.ui.close-search": .init(title: "Close Search", symbol: SBJLayoutSymbology.closeSearch, accessibilityLabel: "Close search"),
    ]
}
