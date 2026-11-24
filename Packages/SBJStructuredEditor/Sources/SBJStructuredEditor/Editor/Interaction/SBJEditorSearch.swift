import SBJStructure
import SBJUIVocabulary
import SBJStructuredReport
#if !os(tvOS) && !os(watchOS)
import SwiftUI

@MainActor
struct SBJEditorSearchBar: View {
    @Binding var searchText: String
    @Binding var criteria: SBJStructuralSearchCriteria
    let hasIssues: Bool?
    let showIssues: () -> Void
    let showStructure: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                SearchField(searching: $searchText, activeSearchBorderPadding: nil)
                SBJToggleButton(
                    SBJStructuredEditorNomenclature.searchChanged,
                    isOn: $criteria.showChangedOnly
                ) {
                    SBJEditorStatusSymbol(kind: .changed)
                }

                SBJToggleButton(
                    SBJStructuredEditorNomenclature.searchEmpty,
                    isOn: $criteria.showEmptyContentOnly
                ) {
                    SBJEditorStatusSymbol(kind: .empty)
                }
            }
            .sbjActiveSearch(!criteria.isEmpty)

			SBJSymbolButton(
                SBJStructuredReportNomenclature.showDefinitionReport,
                action: showStructure
            )

            SBJIssueButton(
                hasIssues: hasIssues,
                action: showIssues
            )
		}
    }
}
#endif
