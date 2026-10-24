import Foundation

// The font representation is a Codable in Localization. Its introspection and
// validation-facing protocol conformance are owned by DataDefinition.
extension CodableFont: SBJMutableStructure {
    public static var sbjProperties: [SBJPropertyMetadata<Self>] {
        [
            .init(sourceName: "family", displayName: "Family", keyPath: \.family),
            .init(sourceName: "size", displayName: "Size", keyPath: \.size, kind: .number),
            .init(sourceName: "weight", displayName: "Weight", keyPath: \.weight),
            .init(sourceName: "italic", displayName: "Italic", keyPath: \.italic, kind: .bool),
            .init(sourceName: "width", displayName: "Width", keyPath: \.width),
        ]
    }

    public static var sbjMutableProperties: [SBJMutableProperty<Self>] {
        [
            .init(name: "Family", \.family),
            .init(name: "Size", \.size),
            .init(name: "Weight", \.weight),
            .init(name: "Italic", \.italic),
            .init(name: "Width", \.width),
        ]
    }

    public var hasContent: Bool { true }
    public func sbjStructuralEquals(_ other: Self) -> Bool { self == other }
    public static func sbjDefaultValue() -> Self? { .init() }

    public func sbjSwiftExpression(using encoder: SBJSwiftEncoder, nested: Bool) -> String {
        // This type uses a non-memberwise public initializer; keep the export
        // expression faithful to its argument labels.
        let familySource = family.map { ".init(\($0.name.debugDescription))" } ?? "nil"
        return "CodableFont(\(familySource), ofSize: \(encoder.floatingPointExpression(size)), weight: .\(weight.rawValue), italic: \(italic), width: .\(width.rawValue))"
    }
}
