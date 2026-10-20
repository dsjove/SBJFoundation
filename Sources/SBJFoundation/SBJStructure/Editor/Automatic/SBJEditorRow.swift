#if !os(tvOS) && !os(watchOS)
import SwiftUI

import SBJDataDefinition
private enum SBJEditorFirstLineCenterID: AlignmentID {
    static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
        min(dimensions.height, 28) / 2
    }
}

private extension VerticalAlignment {
    static let sbjEditorFirstLineCenter = VerticalAlignment(SBJEditorFirstLineCenterID.self)
}

/// Shared visual grammar for one editor row.
///
/// The status marker is a single, fixed leading gutter and never participates in
/// hierarchy indentation. After that comes a deliberately compact hierarchy cue,
/// then only the controls that this particular row actually owns. The content
/// receives all remaining width.
@MainActor
struct SBJEditorRow<Content: View>: View {
    @Environment(SBJEditorPresentationModel.self) private var sbjFormattingModel: SBJEditorPresentationModel?
    private var sbjFormatting: SBJEditorFormattingOptions { sbjFormattingModel?.formattingOptions ?? .init() }
    private let context: SBJEditTraversalContext
    private var treeLevel: Int { context.treeLevel }
    private let disclosureControl: AnyView?
    private let elementAction: AnyView?
    private let optionalControl: AnyView?
    private let showsStatusIndicators: Bool
    private let trailingActions: AnyView?
    private let infoAction: AnyView?
    private let content: Content
    private var indentationWidth: CGFloat { sbjFormatting.indentationWidth }
    private let branch: SBJEditorBranchContext
    private var rowLayoutSuppressed: Bool { branch.placement == .contentOnly }
    private var rowEmbedded: Bool { branch.placement == .embedded }
    private var isChanged: Bool { branch.status.isChanged }
    private var hasContent: Bool? { branch.status.hasContent }
    private var isInvalid: Bool { branch.status.isInvalid }

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        context: SBJEditTraversalContext,
        disclosureControl: AnyView? = nil,
        elementAction: AnyView? = nil,
        optionalControl: AnyView? = nil,
        showsStatusIndicators: Bool = true,
        trailingActions: AnyView? = nil,
        infoAction: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.context = context
        self.branch = context.branch
        self.disclosureControl = disclosureControl
        self.elementAction = elementAction
        self.optionalControl = optionalControl
        self.showsStatusIndicators = showsStatusIndicators
        self.trailingActions = trailingActions
        self.infoAction = infoAction
        self.content = content()
    }

    var body: some View {
        Group {
            if rowLayoutSuppressed {
            content
                .frame(
                    maxWidth: .infinity,
                    minHeight: sbjFormatting.firstLineMinimumHeight,
                    alignment: .leading
                )
        } else if rowEmbedded {
            localRowControlsAndContent
        } else {
            ZStack(alignment: .topLeading) {
                HStack(alignment: .sbjEditorFirstLineCenter, spacing: sbjFormatting.laneSpacing) {
                    if treeLevel > 0 {
                        SBJEditorIndentationBullets(level: treeLevel)
                            .allowsHitTesting(false)
                    }

                    localRowControlsAndContent
                }
                .padding(.leading, sbjFormatting.statusLaneWidth + sbjFormatting.statusToContentSpacing)
                // Every row reserves the same single global info gutter. The
                // property-info container overlays into this space, so nesting
                // never compounds the width cost.
                .padding(.trailing, sbjFormatting.infoLaneWidth + sbjFormatting.laneSpacing)

                if let infoAction {
                    infoAction
                        .frame(width: sbjFormatting.infoLaneWidth, alignment: .center)
                        .frame(minHeight: sbjFormatting.firstLineMinimumHeight, alignment: .center)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            // Validation belongs to the row representing this value. For a
            // compound value that means its header row only; descendants supply
            // their own validation state.
            .background(alignment: .top) {
                if isInvalid && !reduceTransparency {
                    RoundedRectangle(cornerRadius: SBJUIAppearance.fieldCornerRadius)
                        .fill(SBJUIAppearance.invalidFillColor(colorSchemeContrast))
                        .frame(minHeight: sbjFormatting.firstLineMinimumHeight)
                        .allowsHitTesting(false)
                }
            }
            // Read state directly at the row boundary. This prevents a compound
            // container's environment from obscuring or replacing a leaf's own
            // change/content state.
            .overlay {
                if isInvalid && (reduceTransparency || colorSchemeContrast == .increased) {
                    RoundedRectangle(cornerRadius: SBJUIAppearance.fieldCornerRadius)
                        .stroke(
                            SBJUIAppearance.invalidColor,
                            lineWidth: SBJUIAppearance.borderThickness(colorSchemeContrast)
                        )
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topLeading) {
                if showsStatusIndicators {
                    ZStack {
                        if hasContent == false {
                            SBJEditorStatusSymbol(kind: .empty)
                                .foregroundStyle(SBJUIAppearance.emptyColor)
                        }
                        if isChanged {
                            SBJEditorStatusSymbol(kind: .changed)
                                .foregroundStyle(SBJUIAppearance.changedColor)
                        }
                    }
                    .frame(width: sbjFormatting.statusLaneWidth, alignment: .center)
                    .frame(minHeight: sbjFormatting.firstLineMinimumHeight, alignment: .center)
                    .allowsHitTesting(false)
                    .zIndex(2)
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: sbjFormatting.firstLineMinimumHeight,
                alignment: .topLeading
            )
        }
        }
        .onChange(of: isInvalid) { _, newValue in
            sbjFormattingModel?.reportValidationState(newValue)
        }
    }

    private var localRowControlsAndContent: some View {
        let firstLineMinimumHeight = sbjFormatting.firstLineMinimumHeight
        return HStack(alignment: .sbjEditorFirstLineCenter, spacing: sbjFormatting.laneSpacing) {
            if let disclosureControl {
                compactControl(disclosureControl)
            }
            if let elementAction {
                compactControl(elementAction)
            }
            if let optionalControl {
                compactControl(optionalControl)
            }

            content
                .frame(
                    maxWidth: .infinity,
                    minHeight: sbjFormatting.firstLineMinimumHeight,
                    alignment: .leading
                )
                .alignmentGuide(.sbjEditorFirstLineCenter) { dimensions in
                    min(dimensions.height, firstLineMinimumHeight) / 2
                }
                .layoutPriority(1)

            if let trailingActions {
                firstLine(trailingActions)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .frame(maxWidth: .infinity, minHeight: sbjFormatting.firstLineMinimumHeight, alignment: .leading)
    }

    private func compactControl(_ view: AnyView) -> some View {
        let firstLineMinimumHeight = sbjFormatting.firstLineMinimumHeight
        return view
            .frame(width: sbjFormatting.controlLaneWidth, alignment: .center)
            .frame(minHeight: sbjFormatting.firstLineMinimumHeight, alignment: .center)
            .alignmentGuide(.sbjEditorFirstLineCenter) { dimensions in
                min(dimensions.height, firstLineMinimumHeight) / 2
            }
            .fixedSize(horizontal: true, vertical: false)
    }

    private func firstLine(_ view: AnyView) -> some View {
        let firstLineMinimumHeight = sbjFormatting.firstLineMinimumHeight
        return view
            .frame(minHeight: sbjFormatting.firstLineMinimumHeight, alignment: .center)
            .alignmentGuide(.sbjEditorFirstLineCenter) { dimensions in
                min(dimensions.height, firstLineMinimumHeight) / 2
            }
    }
}

/// Closing rule for an expanded disclosure group. The line begins at the
/// center of the final bullet slot belonging to that group's children.
/// The supplied context points to the disclosure's child indentation slot.
@MainActor
struct SBJEditorGroupEnd: View {
    @Environment(SBJEditorPresentationModel.self) private var presentationModel: SBJEditorPresentationModel?
    let indentLevel: Int

    init(indentLevel: Int) { self.indentLevel = indentLevel }
    init(context: SBJEditTraversalContext) { self.indentLevel = context.treeLevel }

    var body: some View {
        let formatting = presentationModel?.formattingOptions ?? .init()
        Divider()
            .padding(.leading, formatting.indentBulletCenter(forLevel: indentLevel))
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
    }
}

@MainActor
struct SBJEditorStatusLane: View {
    @Environment(SBJEditorPresentationModel.self) private var sbjFormattingModel: SBJEditorPresentationModel?
    private var sbjFormatting: SBJEditorFormattingOptions { sbjFormattingModel?.formattingOptions ?? .init() }
    var body: some View {
        ZStack {
            SBJEditorEmptyContentIndicator(hasContent: nil)
            SBJEditorChangeIndicator(isChanged: false)
        }
        .allowsHitTesting(false)
    }
}

@MainActor
struct SBJEditorIndentationBullets: View {
    @Environment(SBJEditorPresentationModel.self) private var sbjFormattingModel: SBJEditorPresentationModel?
    private var sbjFormatting: SBJEditorFormattingOptions { sbjFormattingModel?.formattingOptions ?? .init() }
    let level: Int
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    private var indentationWidth: CGFloat { sbjFormatting.indentationWidth }

    var body: some View {
        let firstLineMinimumHeight = sbjFormatting.firstLineMinimumHeight
        return HStack(spacing: 0) {
            ForEach(0..<level, id: \.self) { _ in
                Circle()
                    .fill(SBJUIAppearance.hierarchyCueColor(colorSchemeContrast))
                    .frame(
                        width: sbjFormatting.indentBulletDiameter,
                        height: sbjFormatting.indentBulletDiameter
                    )
                    .frame(width: indentationWidth)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: CGFloat(level) * indentationWidth, alignment: .leading)
        .frame(minHeight: sbjFormatting.firstLineMinimumHeight, alignment: .leading)
        .alignmentGuide(.sbjEditorFirstLineCenter) { dimensions in
            min(dimensions.height, firstLineMinimumHeight) / 2
        }
        .fixedSize(horizontal: true, vertical: false)
        .allowsHitTesting(false)
    }
}


#endif
