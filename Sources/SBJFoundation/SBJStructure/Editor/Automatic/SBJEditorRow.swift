#if !os(tvOS) && !os(watchOS)
import SwiftUI

private enum SBJEditorFirstLineCenterID: AlignmentID {
    static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
        min(dimensions.height, 28) / 2
    }
}

private extension VerticalAlignment {
    static let sbjEditorFirstLineCenter = VerticalAlignment(SBJEditorFirstLineCenterID.self)
}

private struct SBJEditorRowLayoutSuppressedKey: EnvironmentKey {
    static let defaultValue = false
}

private struct SBJEditorRowEmbeddedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var sbjEditorRowLayoutSuppressed: Bool {
        get { self[SBJEditorRowLayoutSuppressedKey.self] }
        set { self[SBJEditorRowLayoutSuppressedKey.self] = newValue }
    }

    /// Renders a child editor inside a row that already owns the global status,
    /// hierarchy indentation and trailing info gutter. The child keeps only its
    /// local controls (for example an optional clear button) and its content.
    var sbjEditorRowEmbedded: Bool {
        get { self[SBJEditorRowEmbeddedKey.self] }
        set { self[SBJEditorRowEmbeddedKey.self] = newValue }
    }
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
    private let treeLevel: Int
    private let disclosureControl: AnyView?
    private let elementAction: AnyView?
    private let optionalControl: AnyView?
    private let showsStatusIndicators: Bool
    private let trailingActions: AnyView?
    private let infoAction: AnyView?
    private let content: Content
    @Environment(SBJEditorPresentationModel.self) private var presentationModel: SBJEditorPresentationModel?
    private var indentationWidth: CGFloat { presentationModel?.formattingOptions.indentationWidth ?? sbjFormatting.indentationWidth }
    @Environment(\.sbjEditorRowLayoutSuppressed) private var rowLayoutSuppressed
    @Environment(\.sbjEditorRowEmbedded) private var rowEmbedded
    @Environment(\.sbjEditorIsChanged) private var isChanged
    @Environment(\.sbjEditorHasContent) private var hasContent
    @Environment(\.sbjEditorIsInvalid) private var isInvalid
    @Environment(\.sbjEditorValidationStateChanged) private var validationStateChanged
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        treeLevel: Int = 0,
        disclosureControl: AnyView? = nil,
        elementAction: AnyView? = nil,
        optionalControl: AnyView? = nil,
        showsStatusIndicators: Bool = true,
        trailingActions: AnyView? = nil,
        infoAction: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.treeLevel = treeLevel
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
                    RoundedRectangle(cornerRadius: 6)
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
                    RoundedRectangle(cornerRadius: 6)
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
            validationStateChanged(newValue)
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

@MainActor
struct SBJEditorLevelExitDivider: View {
    @Environment(SBJEditorPresentationModel.self) private var sbjFormattingModel: SBJEditorPresentationModel?
    private var sbjFormatting: SBJEditorFormattingOptions { sbjFormattingModel?.formattingOptions ?? .init() }
    let level: Int
    @Environment(SBJEditorPresentationModel.self) private var presentationModel: SBJEditorPresentationModel?
    private var indentationWidth: CGFloat { presentationModel?.formattingOptions.indentationWidth ?? sbjFormatting.indentationWidth }

    var body: some View {
        Divider()
            .allowsHitTesting(false)
            .padding(.leading, sbjFormatting.statusLaneWidth + sbjFormatting.statusToContentSpacing + CGFloat(max(0, level)) * indentationWidth)
    }
}

@MainActor
struct SBJEditorStatusLane: View {
    @Environment(SBJEditorPresentationModel.self) private var sbjFormattingModel: SBJEditorPresentationModel?
    private var sbjFormatting: SBJEditorFormattingOptions { sbjFormattingModel?.formattingOptions ?? .init() }
    var body: some View {
        ZStack {
            SBJEditorEmptyContentIndicator()
            SBJEditorChangeIndicator()
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
    @Environment(SBJEditorPresentationModel.self) private var presentationModel: SBJEditorPresentationModel?
    private var indentationWidth: CGFloat { presentationModel?.formattingOptions.indentationWidth ?? sbjFormatting.indentationWidth }

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
