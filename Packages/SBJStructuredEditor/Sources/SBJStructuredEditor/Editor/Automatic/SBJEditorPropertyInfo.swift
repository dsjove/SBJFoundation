import SBJUIVocabulary
import SBJUnits
#if !os(tvOS) && !os(watchOS)
import SwiftUI

@MainActor
struct SBJEditorPropertyInfoContainer: View {
    @Environment(SBJEditorPresentationModel.self) private var sbjFormattingModel: SBJEditorPresentationModel?
    private var sbjFormatting: SBJEditorFormattingOptions { sbjFormattingModel?.formattingOptions ?? .init() }
    let content: AnyView
    let propertyName: String
    let info: SBJPropertyInfo?
    var caseInfo: (() -> SBJEditorSelectedCaseInfo?)? = nil
    var branch: SBJEditorBranchContext = .init()
    private var rowLayoutSuppressed: Bool { branch.placement == .contentOnly }
    private var rowEmbedded: Bool { branch.placement == .embedded }
    private var propertyInfoInline: Bool { branch.propertyInfoPlacement == .inline }
    private var propertyInfoHidden: Bool { branch.propertyInfoPlacement == .hidden }

    var body: some View {
        Group {
            if propertyInfoHidden {
                if let info {
                    accessible(content, using: info)
                } else {
                    content
                }
            } else if propertyInfoInline, info != nil || caseInfo?() != nil {
                HStack(spacing: sbjFormatting.laneSpacing) {
                    accessibleIfAvailable(content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                    SBJEditorPropertyInfoButton(propertyName: propertyName, info: info, caseInfo: caseInfo)
                        .frame(width: sbjFormatting.infoLaneWidth, alignment: .center)
                        .frame(minHeight: sbjFormatting.firstLineMinimumHeight, alignment: .center)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Property info is normally a global trailing gutter, not a wrapper
                // column. Keeping it as an overlay prevents nested structured editors
                // from losing an info-button lane at every depth.
                Group {
                    if let info {
                        accessible(content, using: info)
                    } else {
                        content
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topTrailing) {
                    if info != nil || caseInfo?() != nil {
                        SBJEditorPropertyInfoButton(propertyName: propertyName, info: info, caseInfo: caseInfo)
                            .frame(width: sbjFormatting.infoLaneWidth, alignment: .center)
                            .frame(minHeight: sbjFormatting.firstLineMinimumHeight, alignment: .center)
                            .offset(
                                x: (rowLayoutSuppressed || rowEmbedded)
                                    ? sbjFormatting.infoLaneWidth + sbjFormatting.laneSpacing
                                    : 0
                            )
                    }
                }
            }
        }
    }

    private func accessibleIfAvailable(_ view: AnyView) -> AnyView {
        guard let info else { return view }
        return accessible(view, using: info)
    }

    private func accessible(_ view: AnyView, using info: SBJPropertyInfo) -> AnyView {
        AnyView(view.accessibility(info))
    }
}

@MainActor
struct SBJEditorPropertyInfoButton: View {
    let propertyName: String
    let info: SBJPropertyInfo?
    var caseInfo: (() -> SBJEditorSelectedCaseInfo?)? = nil
    @State private var isPresented = false

    private var title: String {
        info?.title ?? propertyName
    }

    var body: some View {
        SBJSymbolButton(
            SBJSymbology.information,
            accessibilityLabel: info?.accessibilityLabel ?? "Information about \(title)",
            accessibilityHint: info?.accessibilityHint ?? info?.summary ?? caseInfo?()?.info.summary
        ) {
            isPresented = true
        }
#if os(iOS)
        .popover(isPresented: $isPresented) {
            SBJEditorPropertyInfoSheet(
                title: title,
                info: info,
                caseInfo: caseInfo?(),
                showsDoneButton: false
            ) {
                isPresented = false
            }
            .presentationCompactAdaptation(.popover)
        }
#else
        .sheet(isPresented: $isPresented) {
            SBJEditorPropertyInfoSheet(
                title: title,
                info: info,
                caseInfo: caseInfo?(),
                showsDoneButton: true
            ) {
                isPresented = false
            }
        }
#endif
    }
}

@MainActor
private struct SBJEditorPropertyInfoSheet: View {
    let title: String
    let info: SBJPropertyInfo?
    let caseInfo: SBJEditorSelectedCaseInfo?
    let showsDoneButton: Bool
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Image(symbol: info?.symbol ?? SBJSymbology.information)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title2.weight(.semibold))
                if showsDoneButton {
                    Spacer(minLength: 12)
                    Button("Done", action: dismiss)
                }
            }

            if let info {
                if let summary = info.summary {
                    Text(summary)
                        .font(.subheadline.weight(.semibold))
                }
                if let details = info.details {
                    ScrollView {
                        Text(details)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if let caseInfo {
                if info != nil { Divider().padding(.vertical, 2) }
                Text(caseInfo.title)
                    .font(.headline)
                if let summary = caseInfo.info.summary {
                    Text(summary)
                        .font(.subheadline.weight(.medium))
                }
                if let details = caseInfo.info.details {
                    ScrollView {
                        Text(details)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(14)
        .frame(idealWidth: 440, maxWidth: 520, idealHeight: 320, maxHeight: 520)
    }
}
#endif
