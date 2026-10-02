import Foundation

/// A fundamental value type in SBJFoundation's standard value vocabulary.
///
/// Conformance states the framework-level value requirements explicitly without
/// implying anything about structural exposure, editing, default construction,
/// or presentation. Types may independently conform to `SBJStructured` and other
/// capability protocols.
public protocol SBJFoundationType: Codable, Equatable {}

// Standard Swift/Foundation value types recognized directly by SBJFoundation.
extension String: SBJFoundationType {}
extension Bool: SBJFoundationType {}

extension Int: SBJFoundationType {}
extension Int8: SBJFoundationType {}
extension Int16: SBJFoundationType {}
extension Int32: SBJFoundationType {}
extension Int64: SBJFoundationType {}
extension UInt: SBJFoundationType {}
extension UInt8: SBJFoundationType {}
extension UInt16: SBJFoundationType {}
extension UInt32: SBJFoundationType {}
extension UInt64: SBJFoundationType {}

extension Float: SBJFoundationType {}
extension Double: SBJFoundationType {}
extension CGFloat: SBJFoundationType {}
extension Decimal: SBJFoundationType {}

extension Date: SBJFoundationType {}
extension URL: SBJFoundationType {}
extension UUID: SBJFoundationType {}
extension Data: SBJFoundationType {}
