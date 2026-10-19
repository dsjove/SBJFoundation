import Foundation

/// Declares which broad URL categories are valid for an `@SBJEditable` property.
///
/// Plain `URL` properties require no annotation. Use this annotation only when the
/// model distinguishes file URLs from network URLs. The allowed kinds are checked
/// only when invariant validation is explicitly requested.
///
/// Example: `@SBJURL(allowed: [.file]) var source: URL`
@attached(peer)
public macro SBJURL(allowed: Set<SBJURLKind>) = #externalMacro(
    module: "SBJDataDefinitionMacros",
    type: "SBJURLMacro"
)
