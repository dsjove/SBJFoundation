import SwiftUI
import SBJLocalization

/// Shared non-destructive controls used by playback and PhotoEditor.
public struct ImageEnhancementControls: View {
    @Binding public var adjustments: PhotoColorAdjustments
    @Binding public var isEnabled: Bool

    public init(adjustments: Binding<PhotoColorAdjustments>, isEnabled: Binding<Bool>) {
        _adjustments = adjustments
        _isEnabled = isEnabled
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(SBJImageNomenclature.imageEnhancementHeading.title).font(.headline)
                Spacer()
                Toggle(SBJImageNomenclature.imageEnhancementCompare.title, isOn: $isEnabled)
                    #if !os(tvOS)
                    .toggleStyle(.switch)
                    #endif
                    .help(SBJImageNomenclature.imageEnhancementCompare.details!)
            }
            adjustment(SBJImageNomenclature.imageEnhancementExposure, value: $adjustments.exposure, range: -2...2)
            adjustment(SBJImageNomenclature.imageEnhancementShadows, value: $adjustments.shadows, range: -1...1)
            adjustment(SBJImageNomenclature.imageEnhancementHighlights, value: $adjustments.highlights, range: -1...1)
            adjustment(SBJImageNomenclature.imageEnhancementContrast, value: $adjustments.contrast, range: -1...1)
            adjustment(SBJImageNomenclature.imageEnhancementSaturation, value: $adjustments.saturation, range: -1...1)
            adjustment(SBJImageNomenclature.imageEnhancementDetail, value: $adjustments.detail, range: 0...1)
            adjustment(SBJImageNomenclature.imageEnhancementNoiseReduction, value: $adjustments.noiseReduction, range: 0...1)
            HStack {
                Button(SBJImageNomenclature.imageEnhancementDark.title) { adjustments = .dark; isEnabled = true }
                    .help(SBJImageNomenclature.imageEnhancementDark.details!)
                Button(SBJImageNomenclature.imageEnhancementFaded.title) { adjustments = .faded; isEnabled = true }
                    .help(SBJImageNomenclature.imageEnhancementFaded.details!)
                Button(SBJImageNomenclature.imageEnhancementGrainy.title) { adjustments = .grainy; isEnabled = true }
                    .help(SBJImageNomenclature.imageEnhancementGrainy.details!)
                Spacer()
                Button(SBJImageNomenclature.imageEnhancementReset.title) { adjustments = .init(); isEnabled = true }
                    .help(SBJImageNomenclature.imageEnhancementReset.details!)
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .frame(minWidth: 300, idealWidth: 340)
    }

    private func adjustment(_ nomenclature: SBJNomenclature, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(nomenclature.title)
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
                    .monospacedDigit()
            }
            .font(.caption)
            #if os(tvOS)
            HStack(spacing: 16) {
                Button {
                    let step = (range.upperBound - range.lowerBound) / 20
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(value.wrappedValue <= range.lowerBound)
                .accessibilityLabel("Decrease " + nomenclature.title)

                Spacer()

                Button {
                    let step = (range.upperBound - range.lowerBound) / 20
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(value.wrappedValue >= range.upperBound)
                .accessibilityLabel("Increase " + nomenclature.title)
            }
            #else
            Slider(value: value, in: range)
                .accessibilityLabel(nomenclature.title)
                .accessibilityHint(nomenclature.details!)
            #endif
        }
    }
}
