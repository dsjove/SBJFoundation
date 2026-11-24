import Foundation

/// Named nomenclature values. Stable dictionary keys remain the identifiers used by
/// HTML help and localization; callers use Swift property syntax via dynamic members.
@dynamicMemberLookup
public protocol SBJNomenclatureSet {
    static var all: [String: SBJNomenclature] { get }
}

public extension SBJNomenclatureSet {
    /// Resolves `imageEnhancementReset` to the existing key
    /// `image.enhancement.reset` without changing serialized/help identifiers.
    /// A nonexistent member is a programming error, not missing UI metadata.
    static subscript(dynamicMember name: String) -> SBJNomenclature {
        let matchingKeys = all.keys.filter { normalizedMemberName($0) == normalizedMemberName(name) }
        precondition(matchingKeys.count == 1,
                     "\(Self.self).\(name) must resolve to exactly one nomenclature entry; found \(matchingKeys.count)")
        return all[matchingKeys[0]]!
    }

    private static func normalizedMemberName(_ name: String) -> String {
        String(name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }).lowercased()
    }
}
