import Foundation

extension UnitEditingPolicy: SBJMutableStructure {
    public static var sbjProperties: [SBJPropertyMetadata<Self>] {
        [
            .init(sourceName: "defaultStep", displayName: "Default Step", keyPath: \.defaultStep, kind: .number),
            .init(sourceName: "overrides", displayName: "Overrides", keyPath: \.overrides, kind: .dictionary),
        ]
    }

    public static var sbjMutableProperties: [SBJMutableProperty<Self>] {
        [.init(name: "Default Step", \.defaultStep), .init(name: "Overrides", \.overrides)]
    }

    public var hasContent: Bool { true }
    public func sbjStructuralEquals(_ other: Self) -> Bool { self == other }
    public static func sbjDefaultValue() -> Self? { .init(defaultStep: 1) }
}
