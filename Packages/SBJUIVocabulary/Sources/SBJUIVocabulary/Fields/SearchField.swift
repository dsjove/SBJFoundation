import SwiftUI

import SBJDataDefinition
/// A reusable text field for values that participate in `SearchProtocol`.
public struct SearchField<S: SearchProtocol>: View {
    private let titleKey: LocalizedStringKey
    private let appliesActiveSearchDecoration: Bool
    @Binding private var searching: S

    public init(
        _ titleKey: LocalizedStringKey = "Search",
        searching: Binding<S>,
        appliesActiveSearchDecoration: Bool = true
    ) {
        self.titleKey = titleKey
        self._searching = searching
        self.appliesActiveSearchDecoration = appliesActiveSearchDecoration
    }

    public var body: some View {
        if appliesActiveSearchDecoration {
            searchField
                .sbjActiveSearch(!searching.isEmpty)
        } else {
            searchField
        }
    }

    private var searchField: some View {
        TextField(titleKey, text: $searching.text)
            .sbjSingleLineField()
#if !os(watchOS)
            .autocapitalization(.none)
#endif
            .disableAutocorrection(true)
    }
}
