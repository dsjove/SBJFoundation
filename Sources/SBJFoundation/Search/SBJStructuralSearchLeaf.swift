import Foundation

/// A value that structural search treats as one atomic value rather than
/// recursively inspecting its reflected implementation.
///
/// This capability is intentionally independent of `SBJFoundationType` and
/// `SBJStructured`: a Foundation value may expose structure, and an
/// application-defined value may still choose to be a search leaf.
public protocol SBJStructuralSearchLeaf {}

// These conformances preserve the scalar/Foundation behavior that structural
// search historically handled with a concrete type switch.
extension String: SBJStructuralSearchLeaf {}
extension Character: SBJStructuralSearchLeaf {}
extension Bool: SBJStructuralSearchLeaf {}
extension Int: SBJStructuralSearchLeaf {}
extension Int8: SBJStructuralSearchLeaf {}
extension Int16: SBJStructuralSearchLeaf {}
extension Int32: SBJStructuralSearchLeaf {}
extension Int64: SBJStructuralSearchLeaf {}
extension UInt: SBJStructuralSearchLeaf {}
extension UInt8: SBJStructuralSearchLeaf {}
extension UInt16: SBJStructuralSearchLeaf {}
extension UInt32: SBJStructuralSearchLeaf {}
extension UInt64: SBJStructuralSearchLeaf {}
extension Float: SBJStructuralSearchLeaf {}
extension Double: SBJStructuralSearchLeaf {}
extension Decimal: SBJStructuralSearchLeaf {}
extension Date: SBJStructuralSearchLeaf {}
extension URL: SBJStructuralSearchLeaf {}
extension UUID: SBJStructuralSearchLeaf {}
extension Data: SBJStructuralSearchLeaf {}
