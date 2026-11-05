import SwiftUI

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
                Text("Image Enhancements").font(.headline)
                Spacer()
                Toggle("Before/After", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .help("Disable to compare with the original")
            }
            adjustment("Exposure", value: $adjustments.exposure, range: -2...2)
            adjustment("Shadows", value: $adjustments.shadows, range: -1...1)
            adjustment("Highlights", value: $adjustments.highlights, range: -1...1)
            adjustment("Contrast", value: $adjustments.contrast, range: -1...1)
            adjustment("Saturation", value: $adjustments.saturation, range: -1...1)
            adjustment("Detail", value: $adjustments.detail, range: 0...1)
            adjustment("Noise reduction", value: $adjustments.noiseReduction, range: 0...1)
            HStack {
                Button("Dark") { adjustments = .dark; isEnabled = true }
                Button("Faded") { adjustments = .faded; isEnabled = true }
                Button("Grainy") { adjustments = .grainy; isEnabled = true }
                Spacer()
                Button("Reset") { adjustments = .init(); isEnabled = true }
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .frame(minWidth: 300, idealWidth: 340)
    }

    private func adjustment(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
                    .monospacedDigit()
            }
            .font(.caption)
            Slider(value: value, in: range)
        }
    }
}
