import Foundation
import SBJLocalization

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

extension CodableColor: SBJStructuralComparable {
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        red.sbjStructuralEquals(other.red) && green.sbjStructuralEquals(other.green)
            && blue.sbjStructuralEquals(other.blue) && opacity.sbjStructuralEquals(other.opacity)
    }
}
