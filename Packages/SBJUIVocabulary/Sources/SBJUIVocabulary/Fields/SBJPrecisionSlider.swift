import SwiftUI
import SBJLocalization

/// Precision transport control: a graduated scale with a pointed playhead.
/// A zero-distance drag lets mouse clicks and taps jump directly to position.
public struct SBJPrecisionSlider: View {
    @Binding public var value: Double
    let range: ClosedRange<Double>
    var ticks: Int = 20

    public init(value: Binding<Double>, range: ClosedRange<Double>, ticks: Int = 20) {
        self._value = value
        self.range = range
        self.ticks = ticks
    }

    private var fraction: CGFloat {
        guard range.upperBound > range.lowerBound else { return 0 }
        return CGFloat(min(1, max(0, (value - range.lowerBound) /
                              (range.upperBound - range.lowerBound))))
    }

    public var body: some View {
        #if os(tvOS)
        HStack(spacing: 16) {
            Button {
                let step = (range.upperBound - range.lowerBound) / Double(max(ticks, 1))
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus")
            }
            .disabled(value <= range.lowerBound)
            .accessibilityLabel("Decrease position")

            Text(value.formatted(.number.precision(.fractionLength(2))))
                .monospacedDigit()
                .frame(minWidth: 72)
                .accessibilityLabel(SBJSliderNomenclature.precision.title)

            Button {
                let step = (range.upperBound - range.lowerBound) / Double(max(ticks, 1))
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus")
            }
            .disabled(value >= range.upperBound)
            .accessibilityLabel("Increase position")
        }
        #else
        GeometryReader { proxy in
            let width = max(proxy.size.width - 12, 1)
            let x = 6 + width * fraction
            ZStack(alignment: .leading) {
                Canvas { context, size in
                    let trackY = size.height * 0.47
                    var rail = Path()
                    rail.move(to: CGPoint(x: 6, y: trackY))
                    rail.addLine(to: CGPoint(x: size.width - 6, y: trackY))
                    context.stroke(rail, with: .color(.white.opacity(0.50)), lineWidth: 1.5)
                    for tick in 0...max(ticks, 1) {
                        let location = 6 + width * CGFloat(tick) / CGFloat(max(ticks, 1))
                        let major = tick % 5 == 0
                        var mark = Path()
                        mark.move(to: CGPoint(x: location, y: trackY + 3))
                        mark.addLine(to: CGPoint(x: location, y: trackY + (major ? 10 : 6)))
                        context.stroke(mark, with: .color(.white.opacity(major ? 0.8 : 0.40)), lineWidth: 1)
                    }
                    var played = Path()
                    played.move(to: CGPoint(x: 6, y: trackY))
                    played.addLine(to: CGPoint(x: x, y: trackY))
                    context.stroke(played, with: .color(.white), lineWidth: 2.5)
                }
                Path { path in
                    path.move(to: CGPoint(x: x - 6, y: 1))
                    path.addLine(to: CGPoint(x: x + 6, y: 1))
                    path.addLine(to: CGPoint(x: x, y: 10))
                    path.closeSubpath()
                }
                .fill(.white)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                let portion = min(1, max(0, (gesture.location.x - 6) / width))
                value = range.lowerBound + Double(portion) * (range.upperBound - range.lowerBound)
            })
        }
        .frame(height: 24)
        .accessibilityElement()
        .accessibilityLabel(SBJSliderNomenclature.precision.accessibilityLabel ?? SBJSliderNomenclature.precision.title)
        .accessibilityHint(SBJSliderNomenclature.precision.accessibilityHint ?? SBJSliderNomenclature.precision.summary!)
        .accessibilityValue(String(format: "%.2f", value))
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / Double(max(ticks, 1))
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
        #endif
    }
}

