import Foundation

// These conformances preserve the scalar/Foundation behavior that structural
// search historically handled with a concrete type switch.
extension String: SBJStructuralSearchAtomic {}
extension Character: SBJStructuralSearchAtomic {}
extension Bool: SBJStructuralSearchAtomic {}
extension Int: SBJStructuralSearchAtomic {}
extension Int8: SBJStructuralSearchAtomic {}
extension Int16: SBJStructuralSearchAtomic {}
extension Int32: SBJStructuralSearchAtomic {}
extension Int64: SBJStructuralSearchAtomic {}
extension UInt: SBJStructuralSearchAtomic {}
extension UInt8: SBJStructuralSearchAtomic {}
extension UInt16: SBJStructuralSearchAtomic {}
extension UInt32: SBJStructuralSearchAtomic {}
extension UInt64: SBJStructuralSearchAtomic {}
extension Float: SBJStructuralSearchAtomic {}
extension Double: SBJStructuralSearchAtomic {}
extension Decimal: SBJStructuralSearchAtomic {}
extension Date: SBJStructuralSearchAtomic {}
extension URL: SBJStructuralSearchAtomic {}
extension UUID: SBJStructuralSearchAtomic {}
extension Data: SBJStructuralSearchAtomic {}
