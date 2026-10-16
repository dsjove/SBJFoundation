import SwiftUI

/// Nominal body-text dimensions for a compact field.
///
/// The values are preferences rather than fixed screen-space dimensions. The
/// corresponding view modifier scales them with Dynamic Type before applying
/// them to the view.
struct SBJFieldSizing: Sendable, Equatable {
    let minimum: CGFloat
    let ideal: CGFloat
    let maximum: CGFloat
}
