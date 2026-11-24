import Foundation

/// A value that structural search treats as one atomic value rather than
/// recursively inspecting its reflected implementation.
///
/// This capability is intentionally independent of `Codable, Equatable` and
/// `SBJStructured`: a Foundation value may expose structure, and an
/// application-defined value may still choose to be a atomic search value.
public protocol SBJStructuralSearchAtomic {}

