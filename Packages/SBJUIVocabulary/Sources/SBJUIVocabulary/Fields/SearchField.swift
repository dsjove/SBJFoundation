import SwiftUI

import SBJDataDefinition
/// A reusable text field for values that participate in `SearchProtocol`.
public struct SearchField<S: SearchProtocol>: View {
    private let titleKey: LocalizedStringKey
    private let appliesActiveSearchDecoration: CGFloat?
    @Binding private var searching: S

    public init(
        _ titleKey: LocalizedStringKey = "Search",
        searching: Binding<S>,
        appliesActiveSearchDecoration: CGFloat? = 4
    ) {
        self.titleKey = titleKey
        self._searching = searching
        self.appliesActiveSearchDecoration = appliesActiveSearchDecoration
    }

    public var body: some View {
        searchField
            .sbjActiveSearch(!searching.isEmpty, padding: appliesActiveSearchDecoration)
    }

    private var searchField: some View {
        TextField(titleKey, text: $searching.text)
            .sbjSingleLineField()
#if !os(watchOS) && !os(macOS)
            .autocapitalization(.none)
#endif
            .disableAutocorrection(true)
    }
}
