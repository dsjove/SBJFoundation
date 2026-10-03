/// A value that owns its reconstructable Swift source representation.
///
/// This keeps `SBJSwiftEncoder` dependent on a source-generation capability
/// instead of requiring concrete knowledge of every SBJFoundation value type
/// that needs syntax beyond Swift/Foundation primitives.
public protocol SBJSwiftExpressionRepresentable {
    func sbjSwiftExpression(using encoder: SBJSwiftEncoder, nested: Bool) -> String
}
