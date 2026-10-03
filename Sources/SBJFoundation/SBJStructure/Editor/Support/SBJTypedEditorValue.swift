#if !os(tvOS) && !os(watchOS)
import Foundation
import CoreGraphics

/// Marker for value types that the built-in SwiftUI editor can render directly
/// as leaves without recursively inspecting their structure.
///
/// This protocol is intentionally behavior-free. It replaces duplicated lists of
/// concrete leaf types in editor capability checks while keeping the capability
/// boundary explicit. It is an editor capability, not a Foundation-type or
/// structural-search classification.
public protocol SBJTypedEditorValue {}

extension String: SBJTypedEditorValue {}
extension Bool: SBJTypedEditorValue {}
extension Int: SBJTypedEditorValue {}
extension Int8: SBJTypedEditorValue {}
extension Int16: SBJTypedEditorValue {}
extension Int32: SBJTypedEditorValue {}
extension Int64: SBJTypedEditorValue {}
extension UInt: SBJTypedEditorValue {}
extension UInt8: SBJTypedEditorValue {}
extension UInt16: SBJTypedEditorValue {}
extension UInt32: SBJTypedEditorValue {}
extension UInt64: SBJTypedEditorValue {}
extension Double: SBJTypedEditorValue {}
extension Float: SBJTypedEditorValue {}
extension CGFloat: SBJTypedEditorValue {}
extension Decimal: SBJTypedEditorValue {}
extension Date: SBJTypedEditorValue {}
extension URL: SBJTypedEditorValue {}
extension UUID: SBJTypedEditorValue {}
extension Data: SBJTypedEditorValue {}
extension CodableColor: SBJTypedEditorValue {}
#endif
