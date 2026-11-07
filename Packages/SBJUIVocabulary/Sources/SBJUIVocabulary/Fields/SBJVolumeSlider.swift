import SwiftUI

/// Simple, non-glass volume control. The entire rail, including its trailing
/// portion, remains visible; clicking or dragging anywhere seeks directly.
/// Unlike SBJPrecisionSlider this control has no transport ticks.
public struct SBJVolumeSlider: View {
    @Binding private var value: Double
    private let thumbSize: CGFloat = 10

    public init(value: Binding<Double>) {
        self._value = value
    }

    public var body: some View {
        GeometryReader { geometry in
            let usable = max(geometry.size.width - thumbSize, 1)
            let progress = min(1, max(0, value.isFinite ? value : 0))
            let centerX = thumbSize / 2 + usable * progress

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.40))
                    .frame(height: 3)
                    .padding(.horizontal, thumbSize / 2)

                Capsule()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: usable * progress, height: 3)
                    .offset(x: thumbSize / 2)

                Circle()
                    .fill(Color.accentColor)
                    .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 0.8))
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: centerX - thumbSize / 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                let fraction = (gesture.location.x - thumbSize / 2) / usable
                value = min(1, max(0, Double(fraction)))
            })
        }
        .frame(height: 18)
        .accessibilityElement()
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int((min(1, max(0, value)) * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1, value + 0.05)
            case .decrement: value = max(0, value - 0.05)
            @unknown default: break
            }
        }
    }
}
