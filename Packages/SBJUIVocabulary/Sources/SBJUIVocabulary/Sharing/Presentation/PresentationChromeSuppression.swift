import SwiftUI

/// Environment hook for child presentations that temporarily obscure their
/// parent's presentation chrome.
///
/// The child reports only presentation lifetime. The parent decides what
/// suppression means—for example, temporarily removing a Catalyst toolbar item.
public struct PresentationChromeSuppressionAction: Sendable {
    private let beginAction: @MainActor @Sendable () -> Void
    private let endAction: @MainActor @Sendable () -> Void

    public init(
        begin: @escaping @MainActor @Sendable () -> Void = {},
        end: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.beginAction = begin
        self.endAction = end
    }

    @MainActor
    public func begin() {
        beginAction()
    }

    @MainActor
    public func end() {
        endAction()
    }
}

private struct PresentationChromeSuppressionKey: EnvironmentKey {
    static let defaultValue = PresentationChromeSuppressionAction()
}

public extension EnvironmentValues {
    var presentationChromeSuppression: PresentationChromeSuppressionAction {
        get { self[PresentationChromeSuppressionKey.self] }
        set { self[PresentationChromeSuppressionKey.self] = newValue }
    }
}
