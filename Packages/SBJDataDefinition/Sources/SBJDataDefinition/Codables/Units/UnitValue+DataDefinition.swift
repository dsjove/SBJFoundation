import Foundation

// A unit Codable defined in this package, with structural behavior
// kept separate from its value representation.
extension UnitValue: SBJMutableStructure {
    public static var sbjProperties: [SBJPropertyMetadata<Self>] {
        [
            .init(sourceName: "value", displayName: "Value", keyPath: \.value, kind: .number),
            .init(sourceName: "unit", displayName: "Unit", keyPath: \.unit),
        ]
    }

    public static var sbjMutableProperties: [SBJMutableProperty<Self>] {
        [.init(name: "Value", \.value)]
    }

    public static func sbjDefaultValue() -> Self? {
        Unit.allCases.first.map { .init(0, unit: $0) }
    }

    public func sbjStructuralEquals(_ other: Self) -> Bool { self == other }

    public func sbjSwiftExpression(using encoder: SBJSwiftEncoder, nested: Bool) -> String {
        // The public initializer labels its first argument with `_`, not `value`.
        let sourceUnit = String(describing: unit)
        return "UnitValue<\(String(describing: Unit.self))>(\(encoder.floatingPointExpression(value)), unit: .\(sourceUnit))"
    }

    public func invariant(at keyPath: SBJValidationKeyPath) throws {
        try SBJInvariantCheck.require(value.isFinite, at: keyPath,
                                      "measurement value must be finite")
    }
}
