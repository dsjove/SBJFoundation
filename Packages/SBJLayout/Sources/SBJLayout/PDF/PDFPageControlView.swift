#if !os(watchOS)
import SwiftUI
import SBJLocalization
import SBJUIVocabulary

/// Shared SwiftUI page-navigation and text-search chrome for an SBJLayout PDF controller.
///
/// Search is folded into the existing control so callers keep using the same
/// `PDFPageControlView(controller:)` integration point.
public struct PDFPageControlView<Controller: PDFPageNavigating & PDFTextSearching>: View {
    @Bindable var controller: Controller
    @FocusState private var searchFieldFocused: Bool

    public init(controller: Controller) {
        self.controller = controller
    }

    public var body: some View {
        HStack(spacing: 8) {
            if controller.isSearchPresented {
                searchControls
            } else {
                pageControls
            }
        }
    }

    @ViewBuilder
    private var pageControls: some View {
        let pageRange = controller.currentPage

        SBJSymbolButton(SBJLayoutNomenclature.layoutUiFirstPage, action: controller.goToFirstPage)
        .disabled(!pageRange.canGoBackward)

        SBJSymbolButton(SBJLayoutNomenclature.layoutUiPreviousPage, action: controller.goToPreviousPage)
        .disabled(!pageRange.canGoBackward)

        Text(pageRange.description)
            .monospacedDigit()
            .fixedSize()
            .accessibilityLabel(pageRange.pageAccessibilityLabel)

        SBJSymbolButton(SBJLayoutNomenclature.layoutUiNextPage, action: controller.goToNextPage)
        .disabled(!pageRange.canGoForward)

        SBJSymbolButton(SBJLayoutNomenclature.layoutUiLastPage, action: controller.goToLastPage)
        .disabled(!pageRange.canGoForward)

        SBJSymbolButton(SBJLayoutNomenclature.layoutUiSearchPDF) {
            controller.isSearchPresented = true
            focusSearchField()
        }
    }

    @ViewBuilder
    private var searchControls: some View {
        TextField("Search PDF", text: $controller.searchQuery)
#if !os(tvOS)
            .textFieldStyle(.roundedBorder)
#endif
            .frame(minWidth: 120, idealWidth: 180, maxWidth: 220)
            .focused($searchFieldFocused)
            .submitLabel(.search)
            .onSubmit(controller.goToNextSearchMatch)
            .sbjActiveSearch(controller.isSearchActive, padding: 1)
            .padding(.leading, 8)

        Text(searchMatchDescription)
            .monospacedDigit()
            .fixedSize()
            .accessibilityLabel(searchMatchAccessibilityLabel)

        SBJSymbolButton(SBJLayoutNomenclature.layoutUiPreviousSearchMatch, action: controller.goToPreviousSearchMatch)
        .disabled(controller.searchMatchCount == 0)

        SBJSymbolButton(SBJLayoutNomenclature.layoutUiNextSearchMatch, action: controller.goToNextSearchMatch)
        .disabled(controller.searchMatchCount == 0)

        SBJSymbolButton(SBJLayoutNomenclature.layoutUiCloseSearch, action: closeSearch)
    }

    private var searchMatchDescription: String {
        guard !controller.searchQuery.isEmpty else { return "" }
        guard let current = controller.currentSearchMatchNumber,
              controller.searchMatchCount > 0
        else { return "0/0" }
        return "\(current)/\(controller.searchMatchCount)"
    }

    private var searchMatchAccessibilityLabel: String {
        guard !controller.searchQuery.isEmpty else { return "Enter a search term" }
        guard let current = controller.currentSearchMatchNumber,
              controller.searchMatchCount > 0
        else { return "No search results" }
        return "Search result \(current) of \(controller.searchMatchCount)"
    }

    private func closeSearch() {
        searchFieldFocused = false
        controller.clearSearch()
    }

    private func focusSearchField() {
        Task { @MainActor in
            // Intentional next-turn deferral: SwiftUI must present the search field before focus is requested.
            await Task.yield()
            guard controller.isSearchPresented else { return }
            searchFieldFocused = true
        }
    }
}
#endif
