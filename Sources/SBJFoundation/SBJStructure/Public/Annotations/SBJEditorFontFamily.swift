import SBJDataDefinition
/// Select the built-in font-family chooser for an optional String property.
@attached(peer)
public macro SBJEditorFontFamily() = #externalMacro(module: "SBJFoundationMacros", type: "SBJEditorFontFamilyMacro")
