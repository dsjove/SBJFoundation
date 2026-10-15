#if !os(tvOS) && !os(watchOS)
import SwiftUI
import SBJSubject

@MainActor
struct SBJEditorPropertyInfoContainer: View {
    @Environment(SBJEditorPresentationModel.self) private var sbjFormattingModel: SBJEditorPresentationModel?
    private var sbjFormatting: SBJEditorFormattingOptions { sbjFormattingModel?.formattingOptions ?? .init() }
    let content: AnyView
    let propertyName: String
    let info: SBJPropertyInfo?
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
            } else if propertyInfoInline, let info {
                HStack(spacing: sbjFormatting.laneSpacing) {
                    accessible(content, using: info)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                    SBJEditorPropertyInfoButton(propertyName: propertyName, info: info)
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
                    if let info {
                        SBJEditorPropertyInfoButton(propertyName: propertyName, info: info)
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

    private func accessible(_ view: AnyView, using info: SBJPropertyInfo) -> AnyView {
        AnyView(view.accessibility(info))
    }
}

@MainActor
struct SBJEditorPropertyInfoButton: View {
    let propertyName: String
    let info: SBJPropertyInfo
    @State private var isPresented = false

    private var title: String {
        info.title ?? propertyName
    }

    var body: some View {
        SBJImageButton(
            SBJSemanticImageReference.information,
            accessibilityLabel: info.accessibilityLabel ?? "Information about \(title)",
            accessibilityHint: info.accessibilityHint ?? info.summary
        ) {
            isPresented = true
        }
#if os(iOS)
        .popover(isPresented: $isPresented) {
            SBJEditorPropertyInfoSheet(
                title: title,
                info: info,
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
    let info: SBJPropertyInfo
    let showsDoneButton: Bool
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title2.weight(.semibold))
                if showsDoneButton {
                    Spacer(minLength: 12)
                    Button("Done", action: dismiss)
                }
            }

            Text(info.summary)
                .font(.headline)

            ScrollView {
                Text(info.details)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(idealWidth: 440, maxWidth: 520, idealHeight: 320, maxHeight: 520)
    }
}
#endif
