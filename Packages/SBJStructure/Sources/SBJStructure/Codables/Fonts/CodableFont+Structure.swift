import Foundation

// The font representation has a manually authored structural definition.
extension CodableFont: SBJMutableStructure {
    public static var sbjProperties: [SBJPropertyMetadata<Self>] {
        [
            .init(sourceName: "family", displayName: "Family", keyPath: \.family, visibility: .publicAccess, access: .readWrite),
            .init(sourceName: "size", displayName: "Size", keyPath: \.size, kind: .number, visibility: .publicAccess, access: .readWrite),
            .init(sourceName: "weight", displayName: "Weight", keyPath: \.weight, visibility: .publicAccess, access: .readWrite),
            .init(sourceName: "italic", displayName: "Italic", keyPath: \.italic, kind: .bool, visibility: .publicAccess, access: .readWrite),
            .init(sourceName: "width", displayName: "Width", keyPath: \.width, visibility: .publicAccess, access: .readWrite),
        ]
    }

    public var hasContent: Bool { true }
    public func sbjStructuralEquals(_ other: Self) -> Bool {
        family.sbjStructuralEquals(other.family) && size.sbjStructuralEquals(other.size)
            && weight.sbjStructuralEquals(other.weight) && italic.sbjStructuralEquals(other.italic)
            && width.sbjStructuralEquals(other.width)
    }
    public static func sbjDefaultValue() -> Self? { .init() }

    public func sbjSwiftExpression(using encoder: SBJSwiftEncoder, nested: Bool) -> String {
        // This type uses a non-memberwise public initializer; keep the export
        // expression faithful to its argument labels.
        let familySource = family.map { ".init(\($0.name.debugDescription))" } ?? "nil"
        return "CodableFont(\(familySource), ofSize: \(encoder.floatingPointExpression(size)), weight: .\(weight.rawValue), italic: \(italic), width: .\(width.rawValue))"
    }
}

extension CodableFont.Weight: SBJStructuralScalar {}
extension CodableFont.Width: SBJStructuralScalar {}
