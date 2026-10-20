import SBJUIVocabulary
import SBJUnits
#if !os(tvOS) && !os(watchOS)
/// Rendering policies for an SBJEditorView. Does not hold editor session state.
public struct SBJEditorOptions: Sendable, Equatable {
    /// Transitions are disabled by default until the editor offers explicit animation policies.
    public var animationsEnabled: Bool

    public init(animationsEnabled: Bool = false) {
        self.animationsEnabled = animationsEnabled
    }
}
#endif
