import SBJLocalization

/// A compound business value with an indivisible consumer presentation.
/// Its declared properties remain available to validation, comparison,
/// construction and source export. Consumers use presentedValue for display.
public protocol SBJAtomicStructuralValue: SBJTextPresentable {}

public extension SBJStructuralType {
    static func isAtomic(_ type: Any.Type) -> Bool {
        type is any SBJAtomicStructuralValue.Type
    }
}
