import SBJUIVocabulary
#if !os(watchOS) && !os(tvOS) && canImport(UIKit)
import Observation
import SwiftUI
import SBJDataDefinition

@MainActor
struct SBJSharePresentation: Identifiable {
    let id = UUID()
    let payload: SBJSharePayload
    let onDismiss: (@MainActor @Sendable () -> Void)?
}

/// Explicit owner-facing interface for one stable share presentation surface.
///
/// Pass this object directly to controls that may initiate sharing. It retains
/// the prepared payload until the system share sheet finishes, so callers never
/// need to regenerate expensive activity data during SwiftUI recomputation.
@MainActor
@Observable
public final class SBJSharePresenter {
    var presentation: SBJSharePresentation?

    public init() {}

    public var isPresenting: Bool {
        presentation != nil
    }

    /// Presents a payload that has already been prepared by the caller.
    ///
    /// Returns `false` if this presenter already owns an active presentation.
    @discardableResult
    public func present(
        _ payload: SBJSharePayload,
        onDismiss: (@MainActor @Sendable () -> Void)? = nil
    ) -> Bool {
        guard presentation == nil else { return false }
        presentation = SBJSharePresentation(
            payload: payload,
            onDismiss: onDismiss
        )
        return true
    }

    func finishPresentation() {
        let onDismiss = presentation?.onDismiss
        presentation = nil
        onDismiss?()
    }
}
#endif
