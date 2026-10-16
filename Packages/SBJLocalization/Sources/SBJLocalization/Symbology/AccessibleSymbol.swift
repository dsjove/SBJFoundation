import Foundation

/// Accessibility semantics for a symbol chosen to convey meaning in the interface.
public protocol AccessibleSymbol: Accessible {
    var symbol: SBJSymbol { get }
    var labeled: Bool { get }
    var label: String { get }
}

public extension AccessibleSymbol { var labeled: Bool { false } }

public struct AccessibleSymbolItem: AccessibleSymbol {
    public let symbol: SBJSymbol
    public let labeled: Bool
    public let label: String
    public let accessibility: AccessibleItem
    public var accessibilityLabel: String? { accessibility.accessibilityLabel }
    public var accessibilityHint: String? { accessibility.accessibilityHint }
    public var accessibilityValue: String? { accessibility.accessibilityValue }

    public init(symbol: SBJSymbol, labeled: Bool = false, label: String, hint: String? = nil, value: String? = nil) {
        self.symbol = symbol
        self.labeled = labeled
        self.label = label
        self.accessibility = AccessibleItem(label: labeled ? label : nil, hint: hint, value: value)
    }
}
