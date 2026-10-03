#if !os(tvOS) && !os(watchOS)
import Foundation

enum SBJArrayEditorPresentation {
    static func itemNumber(for underlyingIndex: Int) -> Int {
        underlyingIndex + 1
    }

    static func isDisplayingFilteredSubset(criteria: SBJEditSearchCriteria) -> Bool {
        !criteria.isEmpty
    }
}
#endif
