#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Controls how the editor control uses horizontal space inside
/// ``SBJAdaptiveFieldLayout``.
///
/// Compact scalar/domain values should normally remain intrinsic so rows do
/// not turn every small control into a full-width field. Free-form text is
/// different: there is no useful intrinsic-width signal, so it should consume
/// the space left after its label.
enum SBJAdaptiveFieldControlWidth: Sendable, Equatable {
    case intrinsic
    case fillAvailable(minimum: CGFloat = 120)

    /// The editor width policy for a one-line String field.
    ///
    /// A maximum length gives the editor a meaningful compact sizing hint. An
    /// unconstrained String is free-form and should use the horizontal space
    /// available after its label.
    static func singleLineText(maximumLength: Int?) -> Self {
        maximumLength == nil ? .fillAvailable() : .intrinsic
    }
}
#endif
