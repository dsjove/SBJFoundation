/// Presentation semantics for a structured property.
///
/// These values are UI-independent. An editor may choose an appropriate native
/// control or representation for the requested presentation.
public enum SBJPropertyPresentation: Sendable, Equatable {
    /// Presents an optional String as a font-family choice. `nil` represents the
    /// platform/system font family.
    case fontFamily
}

/// Declares editor-neutral presentation semantics for a property.
///
/// The annotation contributes metadata only; it does not change storage,
/// validation, Codable behavior, or assignment semantics.
@attached(peer)
public macro SBJPresentation(
    _ presentation: SBJPropertyPresentation
) = #externalMacro(module: "SBJFoundationMacros", type: "SBJPresentationMacro")
