#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// A presentation path the stock structured editor can reveal and scroll to.
///
/// Paths use the same human-readable components shown by editor diagnostics.
/// Applications that host ``SBJEditorView`` in ``SBJEditorScrollView`` can call
/// ``SBJEditorViewState/navigate(to:)`` to navigate programmatically.
public struct SBJEditorNavigationTarget: Equatable, Hashable, Sendable {
    public let components: [String]

    public init(components: [String]) {
        self.components = components.map(Self.normalizedComponent).filter { !$0.isEmpty }
    }

    public init(issuePath: String) {
        let separator = issuePath.contains(" • ") ? " • " : " › "
        self.init(components: issuePath.components(separatedBy: separator))
    }

    public var anchor: String { Self.anchor(for: components) }

    func contains(_ navigationPath: [String]) -> Bool {
        let normalizedPath = navigationPath.map(Self.normalizedComponent).filter { !$0.isEmpty }
        guard !normalizedPath.isEmpty, normalizedPath.count <= components.count else { return false }
        return zip(normalizedPath, components).allSatisfy { $0.0 == $0.1 }
    }

    /// Returns true only when the target is below `navigationPath`, not when it
    /// identifies that row itself. Disclosure editors use this to persistently
    /// open ancestors without unnecessarily opening a collection whose own row
    /// is the navigation destination.
    func isDescendant(of navigationPath: [String]) -> Bool {
        let normalizedPath = navigationPath.map(Self.normalizedComponent).filter { !$0.isEmpty }
        guard !normalizedPath.isEmpty, normalizedPath.count < components.count else { return false }
        return zip(normalizedPath, components).allSatisfy { $0.0 == $0.1 }
    }

    static func anchor(for components: [String]) -> String {
        components.map(normalizedComponent).filter { !$0.isEmpty }.joined(separator: "\u{1F}")
    }

    private static func normalizedComponent(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("["), value.hasSuffix("]"), value.count >= 2 {
            value.removeFirst()
            value.removeLast()
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}


private struct SBJEditorNavigationAnchorModifier: ViewModifier {
    let navigationPath: [String]

    func body(content: Content) -> some View {
        content.overlay {
            Color.clear
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .id(SBJEditorNavigationTarget.anchor(for: navigationPath))
        }
    }
}

extension View {
    /// Adds a scroll-navigation anchor without making that mutable navigation
    /// path the SwiftUI identity of the edited content.
    func sbjEditorNavigationAnchor(for navigationPath: [String]) -> some View {
        modifier(SBJEditorNavigationAnchorModifier(navigationPath: navigationPath))
    }
}


struct SBJEditorDisclosureState {
    var userIsExpanded = false

    func resolved(searchIsExpanded: Bool, navigationIsExpanded: Bool) -> Bool {
        userIsExpanded || searchIsExpanded || navigationIsExpanded
    }

    mutating func setUserExpansion(_ isExpanded: Bool, searchIsExpanded: Bool) {
        guard !searchIsExpanded else { return }
        userIsExpanded = isExpanded
    }

    mutating func commitNavigationExpansion(
        target: SBJEditorNavigationTarget?,
        path: [String]
    ) {
        guard target?.isDescendant(of: path) == true else { return }
        userIsExpanded = true
    }
}

private struct SBJEditorNavigationTargetKey: EnvironmentKey {
    static let defaultValue: SBJEditorNavigationTarget? = nil
}

extension EnvironmentValues {
    var sbjEditorNavigationTarget: SBJEditorNavigationTarget? {
        get { self[SBJEditorNavigationTargetKey.self] }
        set { self[SBJEditorNavigationTargetKey.self] = newValue }
    }
}

/// Stock scrolling container for ``SBJEditorView``.
///
/// It listens to ``SBJEditorViewState/navigationTarget`` so issue navigation can
/// reveal the requested property and then scroll it into view. Clients that need
/// custom scrolling can continue to host ``SBJEditorView`` directly and observe
/// the same navigation target themselves.
public struct SBJEditorScrollView<Content: View>: View {
    @Binding private var state: SBJEditorViewState
    private let content: Content

    public init(
        state: Binding<SBJEditorViewState>,
        @ViewBuilder content: () -> Content
    ) {
        self._state = state
        self.content = content()
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content
            }
            .task(id: state.navigationRevision) {
                guard let target = state.navigationTarget else { return }

                // Navigation can expand several disclosure ancestors. Those
                // descendants are materialized over more than one SwiftUI layout
                // pass, so a single immediate scroll can use a stale content
                // height and leave the destination clipped near an edge.
                await Task.yield()
                await Task.yield()
                guard !Task.isCancelled, state.navigationTarget == target else { return }

                // First pass makes the newly materialized destination visible.
                proxy.scrollTo(target.anchor, anchor: .center)

                // Give disclosure expansion and the scroll view's content-size
                // update a frame to settle, then center against the final layout.
                do {
                    try await Task.sleep(for: .milliseconds(80))
                } catch {
                    return
                }
                guard !Task.isCancelled, state.navigationTarget == target else { return }
                proxy.scrollTo(target.anchor, anchor: .center)

                if state.navigationTarget == target {
                    state.navigationTarget = nil
                }
            }
        }
    }
}
#endif
