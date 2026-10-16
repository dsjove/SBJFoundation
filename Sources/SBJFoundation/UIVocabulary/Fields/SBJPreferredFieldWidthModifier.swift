import SwiftUI

struct SBJPreferredFieldWidthModifier: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var minimum: CGFloat = 0
    @ScaledMetric(relativeTo: .body) private var ideal: CGFloat = 0
    @ScaledMetric(relativeTo: .body) private var maximum: CGFloat = 0

    init(sizing: SBJFieldSizing) {
        _minimum = ScaledMetric(wrappedValue: sizing.minimum, relativeTo: .body)
        _ideal = ScaledMetric(wrappedValue: sizing.ideal, relativeTo: .body)
        _maximum = ScaledMetric(wrappedValue: sizing.maximum, relativeTo: .body)
    }

    func body(content: Content) -> some View {
        content.frame(
            minWidth: minimum,
            idealWidth: ideal,
            maxWidth: maximum,
            alignment: .leading
        )
    }
}

extension View {
    /// Keeps a compact field near its preferred width without freezing it to
    /// one point size. Nominal sizing scales with Dynamic Type.
    func sbjPreferredFieldWidth(_ sizing: SBJFieldSizing) -> some View {
        modifier(SBJPreferredFieldWidthModifier(sizing: sizing))
    }
}
