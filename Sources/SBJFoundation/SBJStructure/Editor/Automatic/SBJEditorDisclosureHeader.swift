#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Shared disclosure row used by the generated editor.
///
/// Disclosure, element actions, state indicators, title content and trailing
/// actions occupy explicit semantic lanes. Controls are aligned to the first
/// row, so expanding a multiline/compound value never shifts their vertical
/// position.
struct SBJEditorDisclosureHeader: View {
    let title: String
    let treeLevel: Int
    @Binding var isExpanded: Bool
    let leadingActions: AnyView
    let optionalControl: AnyView?
    let trailingActions: AnyView
    let infoAction: AnyView?
    let titleIsUnknown: Bool
    let titleContent: AnyView?
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        _ title: String,
        treeLevel: Int = 0,
        isExpanded: Binding<Bool>,
        leadingActions: AnyView = AnyView(EmptyView()),
        optionalControl: AnyView? = nil,
        trailingActions: AnyView = AnyView(EmptyView()),
        infoAction: AnyView? = nil,
        titleIsUnknown: Bool = false,
        titleContent: AnyView? = nil
    ) {
        self.title = title
        self.treeLevel = treeLevel
        self._isExpanded = isExpanded
        self.leadingActions = leadingActions
        self.optionalControl = optionalControl
        self.trailingActions = trailingActions
        self.infoAction = infoAction
        self.titleIsUnknown = titleIsUnknown
        self.titleContent = titleContent
    }

    var body: some View {
        SBJEditorRow(
            treeLevel: treeLevel,
            disclosureControl: AnyView(
                SBJDisclosureButton(title, isExpanded: $isExpanded)
                    .accessibilityHidden(titleContent == nil)
            ),
            elementAction: leadingActions,
            optionalControl: optionalControl,
            trailingActions: trailingActions,
            infoAction: infoAction
        ) {
            if let titleContent {
                titleContent
                    .frame(
                        maxWidth: .infinity,
                        minHeight: SBJEditorRowMetrics.firstLineMinimumHeight,
                        alignment: .leading
                    )
            } else {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 8) {
                        if titleIsUnknown {
                            Text(title)
                                .fontWeight(.semibold)
                                .italic()
                        } else {
                            Text(title)
                                .fontWeight(.semibold)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: SBJEditorRowMetrics.firstLineMinimumHeight,
                        alignment: .leading
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                .accessibilityHint(isExpanded ? "Activate to collapse" : "Activate to expand")
            }
        }
        .padding(.vertical, 2)
        .background {
            if !reduceTransparency {
                SBJUIAppearance.headerFillColor(colorSchemeContrast)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onAppear {
            if isExpanded { isExpanded = true }
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded { isExpanded = true }
        }
    }

}
#endif
