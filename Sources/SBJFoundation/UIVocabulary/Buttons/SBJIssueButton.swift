import SwiftUI
import SBJDataDefinition
import SBJLocalization

@MainActor
public struct SBJIssueButton: View {
    public let hasIssues: Bool?
    private let accessibilityLabel: String
    private let action: () -> Void

    public init(
        hasIssues: Bool?,
        accessibilityLabel: String = "Show issues",
        action: @escaping () -> Void
    ) {
        self.hasIssues = hasIssues
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    @ViewBuilder
    public var body: some View {
        if hasIssues != false {
            SBJImageButton(
                SBJSymbology.issues,
                accessibilityLabel: accessibilityLabel,
                action: action
            )
            .foregroundStyle(hasIssues == true ? SBJUIAppearance.issueColor : SBJUIAppearance.inactiveControlColor)
        }
    }
}
