import SwiftUI

import SBJDataDefinition
// TODO: Revisit the FieldSizing model alongside localization candidate fitting.
// The current min/ideal/max values are width preferences, not measured text extents.
// Decide whether to represent measured content, padding, font metrics, and layout
// constraints explicitly instead of treating nominal point values as universal.
// Keep editable-field sizing separate from selecting localized display wording.
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
