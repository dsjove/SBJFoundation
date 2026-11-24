/// The public nomenclature fields are themselves described by nomenclature, so
/// reporting and semantic discovery can reuse their descriptions without
/// embedding them in prompts or presentation code.
public extension SBJNomenclature {
    static let titleNomenclature = SBJNomenclature(
        title: "Title", summary: "The primary human-readable name of the item."
    )
    static let summaryNomenclature = SBJNomenclature(
        title: "Summary", summary: "A concise explanation of the item."
    )
    static let detailsNomenclature = SBJNomenclature(
        title: "Details", summary: "The complete description, including usage guidance."
    )
    static let aliasesNomenclature = SBJNomenclature(
        title: "Aliases", summary: "Alternative terms used to find the item."
    )
    static let symbolNomenclature = SBJNomenclature(
        title: "Symbol", summary: "The visual symbol associated with the item."
    )
    static let accessibilityLabelNomenclature = SBJNomenclature(
        title: "Accessibility Label", summary: "An explicit accessible name override."
    )
    static let accessibilityHintNomenclature = SBJNomenclature(
        title: "Accessibility Hint", summary: "An explicit accessible usage hint."
    )
}
