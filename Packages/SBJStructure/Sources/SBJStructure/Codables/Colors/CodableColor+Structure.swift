import Foundation

extension CodableColor: SBJDefaultValueCreatable, SBJSwiftExpressionRepresentable {
    public static func sbjCreateDefaultValueIfPossible() -> Self? { .init() }

    public func sbjSwiftExpression(using encoder: SBJSwiftEncoder, nested: Bool) -> String {
        var components = [
            encoder.floatingPointExpression(red),
            encoder.floatingPointExpression(green),
            encoder.floatingPointExpression(blue)
        ]
        if opacity != 1.0 { components.append(encoder.floatingPointExpression(opacity)) }
        return ".init(\(components.joined(separator: ", ")))"
    }
}
