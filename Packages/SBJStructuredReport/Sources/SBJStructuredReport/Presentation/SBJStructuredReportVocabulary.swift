import SBJLocalization

/// Semantic symbols for report-specific capabilities, including actions triggered by consumers.
public enum SBJStructuredReportSymbology: SBJSymbolSet {
    public static let all: [String: SBJSymbol] = [
        "showDefinitionReport": .system("doc.richtext"),
        "sortReport": .system("arrow.up.arrow.down"),
    ]
}

/// Shared nomenclature used by the UI and help. The UI and help consume these same nomenclature definitions.
public enum SBJStructuredReportNomenclature: SBJNomenclatureSet {
    public static let showDefinitionReport = SBJNomenclature(title: "Structure Report", symbol: SBJStructuredReportSymbology.showDefinitionReport, accessibilityHint: "Show structure report")
    public static let sortReport = SBJNomenclature(title: "Sort report", symbol: SBJStructuredReportSymbology.sortReport)
    public static let all: [String: SBJNomenclature] = [
        "structured-report.ui.show-definition-report": showDefinitionReport,
        "structured-report.ui.sort-report": sortReport,
        "structured-report.ui.share-pdf": .init(title: "Share PDF", details: "Share the generated structure report as a PDF.", symbol: .system("square.and.arrow.up")),
    ]
}
