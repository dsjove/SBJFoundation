/// Compile-time case-name metadata synthesized for enums annotated with `@SBJStructure`.
///
/// Swift's runtime reflection does not reliably expose an enum case's source spelling,
/// especially when the enum uses presentation-oriented raw values or descriptions.
/// `@SBJStructure` therefore records the declared case names while the source is
/// available to the macro.
public protocol SBJStructuredEnum {
    /// Swift source names of all cases, in declaration order.
    static var sbjCaseNames: [String] { get }

    /// Returns the Swift source name for an enum value of this type.
    ///
    /// This static entry point keeps the per-instance generated convenience property
    /// from becoming public API solely to satisfy the exporter.
    static func sbjCaseName(for value: Any) -> String?
}
