import Foundation

/// Supplies a type's default human-facing meaning independently of structural metadata.
/// Property-specific nomenclature can override each attribute independently.
public protocol SBJNomenclatureProviding {
    static var nomenclature: SBJNomenclature { get }
}

extension Optional: SBJNomenclatureProviding where Wrapped: SBJNomenclatureProviding {
    public static var nomenclature: SBJNomenclature { Wrapped.nomenclature }
}

public extension SBJNomenclature {
    /// Fills absent attributes from the defaults without mutating either value.
    func mergingDefaults(from defaults: SBJNomenclature) -> SBJNomenclature {
        SBJNomenclature(
            title: nonEmptyTitle ?? defaults.title,
            summary: summary ?? defaults.summary,
            details: details ?? defaults.details,
            aliases: aliases.isEmpty ? defaults.aliases : aliases,
            symbol: symbol ?? defaults.symbol,
            accessibilityLabel: accessibilityLabel ?? defaults.accessibilityLabel,
            accessibilityHint: accessibilityHint ?? defaults.accessibilityHint
        )
    }
}

/// Resolves optional property-specific terminology against defaults supplied by its value type.
/// Types without a provider retain the exact property value, including nil.
public enum SBJNomenclatureResolver {
    public static func resolve<Value>(
        _ propertyNomenclature: SBJNomenclature?, for type: Value.Type
    ) -> SBJNomenclature? {
        guard let provider = type as? any SBJNomenclatureProviding.Type else {
            return propertyNomenclature
        }
        let defaults = provider.nomenclature
        return propertyNomenclature?.mergingDefaults(from: defaults) ?? defaults
    }
}
