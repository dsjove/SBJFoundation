import SwiftUI
import SBJLocalization
import SBJUIVocabulary

@MainActor
public struct SBJIssueButton: View {
    public let hasIssues: Bool?
    private let action: () -> Void

    public init(
        hasIssues: Bool?,
        action: @escaping () -> Void
    ) {
        self.hasIssues = hasIssues
        self.action = action
    }

    @ViewBuilder
    public var body: some View {
        if hasIssues != false {
            SBJSymbolButton(
                hasIssues == nil ? SBJStructuredEditorNomenclature.checkIssues : SBJStructuredEditorNomenclature.issues,
                action: action
            )
            .foregroundStyle(hasIssues == true ? SBJUIAppearance.issueColor : SBJUIAppearance.inactiveControlColor)
        }
    }
}
