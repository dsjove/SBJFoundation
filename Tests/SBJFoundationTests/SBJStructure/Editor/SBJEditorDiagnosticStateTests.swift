import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import SwiftUI
import SBJDataDefinition
import Testing
@testable import SBJFoundation

@MainActor
@Suite("Editor diagnostic state")
struct SBJEditorDiagnosticStateTests {
    @Test("Issue indicator is derived from one cached diagnostic list")
    func issueStatus() {
        let model = SBJEditorPresentationModel(expansionOptions: .sessionOnly)
        #expect(model.issues == nil)
        #expect(model.hasIssues == nil)

        model.replaceIssues([])
        #expect(model.hasIssues == false)

        model.replaceIssues([
            .validation(path: "Example", message: "Invalid value")
        ])
        #expect(model.hasIssues == true)
        #expect(model.issues?.count == 1)

        model.replaceIssues([])
        #expect(model.hasIssues == false)
    }

    @Test("Row validity changes invalidate diagnostics without inventing issue entries")
    func validationInvalidation() {
        let model = SBJEditorPresentationModel(expansionOptions: .sessionOnly)
        model.replaceIssues([])
        let initialRevision = model.issueResolutionRevision
        model.reportValidationState(true)
        #expect(model.issueResolutionRevision == initialRevision + 1)
        #expect(model.hasIssues == false)
        model.reportValidationState(false)
        #expect(model.issueResolutionRevision == initialRevision + 2)
        #expect(model.issues?.isEmpty == true)
    }
}
#endif
