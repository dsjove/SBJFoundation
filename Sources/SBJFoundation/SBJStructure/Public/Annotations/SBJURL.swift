import Foundation

/// Broad URL categories that can be declared as valid for an `@SBJStructure` property.
///
/// `.file` accepts file URLs. `.network` accepts absolute, non-file URLs with a
/// scheme. The declaration is a model invariant only; it does not restrict direct
/// assignment or what `SBJCodableEditor` lets a user enter.
public enum SBJURLKind: Sendable, Hashable {
    case file
    case network
}

/// Declares which broad URL categories are valid for an `@SBJStructure` property.
///
/// Plain `URL` properties require no annotation. Use this annotation only when the
/// model distinguishes file URLs from network URLs. The allowed kinds are checked
/// only when invariant validation is explicitly requested.
///
/// Example: `@SBJURL(allowed: [.file]) var source: URL`
@attached(peer)
public macro SBJURL(allowed: Set<SBJURLKind>) = #externalMacro(
    module: "SBJFoundationMacros",
    type: "SBJURLMacro"
)
