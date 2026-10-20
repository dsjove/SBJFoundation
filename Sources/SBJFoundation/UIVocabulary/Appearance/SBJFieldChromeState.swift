import SwiftUI

/// Independent visual states that may coexist on a field.
struct SBJFieldChromeState: OptionSet, Sendable {
    let rawValue: UInt8

    init(rawValue: UInt8) { self.rawValue = rawValue }

    static let focused = Self(rawValue: 1 << 0)
    static let selected = Self(rawValue: 1 << 1)
    static let invalid = Self(rawValue: 1 << 2)
    static let standard: Self = []
}
