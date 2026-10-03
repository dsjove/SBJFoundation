/// Exposes a writable computed property to `SBJCodableEditor` without making it
/// part of `@SBJStructure` structural metadata, content inspection, Codable
/// structure, or invariant validation.
///
/// Use this for editor-facing adapters whose value is derived from or bridged to
/// separately managed storage, such as an image, document, or other UI-oriented
/// value. The property must provide a writable key path (normally `get` and
/// `set` accessors).
@attached(peer)
public macro SBJEditorProperty() = #externalMacro(
    module: "SBJFoundationMacros",
    type: "SBJEditorPropertyMacro"
)
