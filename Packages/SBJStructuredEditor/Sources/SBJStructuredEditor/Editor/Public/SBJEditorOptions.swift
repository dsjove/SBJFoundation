import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
/// Rendering policies for an SBJEditorView. Does not hold editor session state.
public struct SBJEditorOptions: Sendable, Equatable {
    /// Transitions are disabled by default until the editor offers explicit animation policies.
    public var animationsEnabled: Bool

    /// Include immutable stored and read-only computed properties in the editor.
    public var showsReadOnlyProperties: Bool

    public init(animationsEnabled: Bool = false, showsReadOnlyProperties: Bool = false) {
        self.animationsEnabled = animationsEnabled
        self.showsReadOnlyProperties = showsReadOnlyProperties
    }
}
#endif
