import SwiftUI
import SBJLocalization

/// A search field whose static presentation and accessibility information come
/// from the same nomenclature used by help and other UI surfaces.
public struct SearchField<S: SearchProtocol>: View {
    private let nomenclature: SBJNomenclature
    private let context: String?
    private let activeSearchBorderPadding: CGFloat?
    @Binding private var searching: S

    public init(
        _ nomenclature: SBJNomenclature = SBJCommonNomenclature.search,
        context: String? = nil,
        searching: Binding<S>,
        activeSearchBorderPadding: CGFloat? = SBJUIAppearance.activeSearchStrokeWidth + 0.5
    ) {
        self.nomenclature = nomenclature
        self.context = context
        self._searching = searching
        self.activeSearchBorderPadding = activeSearchBorderPadding
    }

    public var body: some View {
        searchField
            .sbjActiveSearch(!searching.isEmpty, padding: activeSearchBorderPadding)
    }

    private var searchField: some View {
        let title = nomenclature.title
        let displayedTitle = context.map { "\(title) \($0)" } ?? title
        let spokenTitle = nomenclature.accessibilityLabel ?? title
        let accessibilityTitle = context.map { "\(spokenTitle) \($0)" } ?? spokenTitle
        return TextField(displayedTitle, text: $searching.text)
            .sbjSingleLineField()
#if !os(watchOS) && !os(macOS)
            .autocapitalization(.none)
#endif
            .disableAutocorrection(true)
            .accessibility(label: accessibilityTitle, hint: nomenclature.accessibilityHint ?? nomenclature.summary)
    }
}
