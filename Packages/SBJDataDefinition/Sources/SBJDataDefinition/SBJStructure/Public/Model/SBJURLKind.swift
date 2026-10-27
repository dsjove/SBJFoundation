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
