
#if !os(tvOS) && !os(watchOS)
import SwiftUI
import SBJUIVocabulary

@MainActor
struct SBJEditorNomenclatureContainer: View {
    @Environment(SBJEditorPresentationModel.self) private var sbjFormattingModel: SBJEditorPresentationModel?
    private var sbjFormatting: SBJEditorFormattingOptions { sbjFormattingModel?.formattingOptions ?? .init() }
    let content: AnyView
    let propertyName: String
    let info: SBJNomenclature?
    var caseInfo: (() -> SBJEditorSelectedCaseInfo?)? = nil
    var branch: SBJEditorBranchContext = .init()
    private var rowLayoutSuppressed: Bool { branch.placement == .contentOnly }
    private var rowEmbedded: Bool { branch.placement == .embedded }
    private var nomenclatureInline: Bool { branch.nomenclaturePlacement == .inline }
    private var nomenclatureHidden: Bool { branch.nomenclaturePlacement == .hidden }

    var body: some View {
        Group {
            if nomenclatureHidden {
                if let info {
                    accessible(content, using: info)
                } else {
                    content
                }
            } else if nomenclatureInline, info != nil || caseInfo?() != nil {
                HStack(spacing: sbjFormatting.laneSpacing) {
                    accessibleIfAvailable(content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                    SBJNomenclatureButton(propertyName: propertyName, info: info, additionalInfo: {
                        caseInfo?().map { (title: $0.title, info: $0.info) }
                    })
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
                        SBJNomenclatureButton(propertyName: propertyName, info: info, additionalInfo: {
                        caseInfo?().map { (title: $0.title, info: $0.info) }
                    })
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

    private func accessible(_ view: AnyView, using info: SBJNomenclature) -> AnyView {
        AnyView(view.accessibility(info))
    }
}

#endif
