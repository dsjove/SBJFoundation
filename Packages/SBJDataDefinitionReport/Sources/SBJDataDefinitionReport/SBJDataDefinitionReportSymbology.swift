import SBJLocalization

/// Semantic symbols for report-specific capabilities, including actions triggered by consumers.
public enum SBJDataDefinitionReportSymbology: SBJSymbolSet {
    public static let all: [String: SBJSymbol] = [
        "showDefinitionReport": .system("doc.richtext"),
        "sortReport": .system("arrow.up.arrow.down"),
    ]
}

public extension SBJDataDefinitionReportSymbology {
    static var showDefinitionReportLabel: SBJLabeledSymbol {
        SBJLabeledSymbol(symbol: self.showDefinitionReport, title: "Structure Report", accessibilityHint: "Show structure report")
    }
    static var sortReportLabel: SBJLabeledSymbol { SBJLabeledSymbol(symbol: self.sortReport, title: "Sort report") }
}
