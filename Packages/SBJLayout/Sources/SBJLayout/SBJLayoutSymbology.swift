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
    static var pageLayoutLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.pageLayout, title: "Page Layout", accessibilityLabel: "Edit page layout", accessibilityHint: "Configure page layout")
    }
    static var firstPageLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.firstPage, title: "First Page", accessibilityLabel: "Go to first page")
    }
    static var previousPageLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.previousPage, title: "Previous Page", accessibilityLabel: "Go to previous page")
    }
    static var nextPageLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.nextPage, title: "Next Page", accessibilityLabel: "Go to next page")
    }
    static var lastPageLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.lastPage, title: "Last Page", accessibilityLabel: "Go to last page")
    }
    static var searchPDFLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.searchPDF, title: "Search PDF", accessibilityLabel: "Search PDF")
    }
    static var previousSearchMatchLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.previousSearchMatch, title: "Previous Match", accessibilityLabel: "Go to previous search result")
    }
    static var nextSearchMatchLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.nextSearchMatch, title: "Next Match", accessibilityLabel: "Go to next search result")
    }
    static var closeSearchLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.closeSearch, title: "Close Search", accessibilityLabel: "Close search")
    }
}
