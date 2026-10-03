#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// A label/control pair that preserves the compact editor grammar when it fits,
/// but stacks vertically when Dynamic Type or translated text needs more room.
///
/// The layout is deliberately content-driven rather than locale-driven. Leading
/// and trailing remain semantic, so SwiftUI mirrors the result automatically in
/// right-to-left environments.
@MainActor
struct SBJAdaptiveFieldLayout<Label: View, Control: View>: View {
    private let spacing: CGFloat
    private let controlWidth: SBJAdaptiveFieldControlWidth
    private let label: Label
    private let control: Control
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        spacing: CGFloat = 8,
        controlWidth: SBJAdaptiveFieldControlWidth = .intrinsic,
        @ViewBuilder label: () -> Label,
        @ViewBuilder control: () -> Control
    ) {
        self.spacing = spacing
        self.controlWidth = controlWidth
        self.label = label()
        self.control = control()
    }

    @ViewBuilder
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            vertical
        } else {
            switch controlWidth {
            case .intrinsic:
                ViewThatFits(in: .horizontal) {
                    intrinsicHorizontal
                        .fixedSize(horizontal: true, vertical: false)
                    vertical
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            case .fillAvailable:
                // A free-form field has no meaningful preferred text width.
                // Let it consume the remainder of the row. The minimum width
                // on the horizontal candidate still gives ViewThatFits a point
                // at which to choose the stacked presentation.
                ViewThatFits(in: .horizontal) {
                    fillHorizontal
                    vertical
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var intrinsicHorizontal: some View {
        HStack(alignment: .center, spacing: spacing) {
            fixedLabel
            HStack(spacing: spacing) {
                control
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    @ViewBuilder
    private var fillHorizontal: some View {
        switch controlWidth {
        case .intrinsic:
            intrinsicHorizontal

        case .fillAvailable(let minimum):
            HStack(alignment: .center, spacing: spacing) {
                fixedLabel
                control
                    .frame(minWidth: minimum, maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var vertical: some View {
        VStack(alignment: .leading, spacing: 4) {
            label
            switch controlWidth {
            case .intrinsic:
                HStack(spacing: spacing) {
                    control
                }
                .fixedSize(horizontal: true, vertical: false)

            case .fillAvailable:
                control
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fixedLabel: some View {
        label
            .fixedSize(horizontal: true, vertical: false)
    }
}
#endif
