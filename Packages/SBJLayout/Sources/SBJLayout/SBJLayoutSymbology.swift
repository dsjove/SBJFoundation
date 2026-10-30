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

public extension SBJLayoutSymbology {
    static var pageLayoutLabel: LabeledSymbol {
        LabeledSymbol(symbol: self.pageLayout, title: "Page Layout", accessibilityLabel: "Edit page layout", accessibilityHint: "Configure page layout")
    }
    static var firstPageLabel: LabeledSymbol {
        LabeledSymbol(symbol: self.firstPage, title: "First Page", accessibilityLabel: "Go to first page")
    }
    static var previousPageLabel: LabeledSymbol {
        LabeledSymbol(symbol: self.previousPage, title: "Previous Page", accessibilityLabel: "Go to previous page")
    }
    static var nextPageLabel: LabeledSymbol {
        LabeledSymbol(symbol: self.nextPage, title: "Next Page", accessibilityLabel: "Go to next page")
    }
    static var lastPageLabel: LabeledSymbol {
        LabeledSymbol(symbol: self.lastPage, title: "Last Page", accessibilityLabel: "Go to last page")
    }
    static var searchPDFLabel: LabeledSymbol {
        LabeledSymbol(symbol: self.searchPDF, title: "Search PDF", accessibilityLabel: "Search PDF")
    }
    static var previousSearchMatchLabel: LabeledSymbol {
        LabeledSymbol(symbol: self.previousSearchMatch, title: "Previous Match", accessibilityLabel: "Go to previous search result")
    }
    static var nextSearchMatchLabel: LabeledSymbol {
        LabeledSymbol(symbol: self.nextSearchMatch, title: "Next Match", accessibilityLabel: "Go to next search result")
    }
    static var closeSearchLabel: LabeledSymbol {
        LabeledSymbol(symbol: self.closeSearch, title: "Close Search", accessibilityLabel: "Close search")
    }
}
