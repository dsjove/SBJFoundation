import SBJLocalization

/// Optional, reusable documentation for a value type. Property-specific
/// metadata overrides these defaults independently for each attribute.
public protocol SBJDefinitionTypeInfoProviding {
    static var definitionTypeInfo: SBJPropertyInfo { get }
}

extension Optional: SBJDefinitionTypeInfoProviding where Wrapped: SBJDefinitionTypeInfoProviding {
    public static var definitionTypeInfo: SBJPropertyInfo { Wrapped.definitionTypeInfo }
}

public extension SBJPropertyInfo {
    /// Fill only missing attributes using the supplied defaults.
    /// Neither value is mutated.
    func mergingDefaults(from defaults: SBJPropertyInfo) -> SBJPropertyInfo {
        SBJPropertyInfo(
            title: title ?? defaults.title,
            summary: summary ?? defaults.summary,
            details: details ?? defaults.details,
            symbol: symbol ?? defaults.symbol,
            accessibilityLabel: accessibilityLabel ?? defaults.accessibilityLabel,
            accessibilityHint: accessibilityHint ?? defaults.accessibilityHint
        )
    }
}

/// Resolves absent property information against value-type defaults, if any.
/// No fabricated metadata is produced for types without a provider.
public enum SBJDefinitionTypeInfo {
    public static func resolve<Value>(
        _ propertyInfo: SBJPropertyInfo?,
        for type: Value.Type
    ) -> SBJPropertyInfo? {
        guard let provider = type as? any SBJDefinitionTypeInfoProviding.Type else {
            return propertyInfo
        }
        let defaults = provider.definitionTypeInfo
        return propertyInfo?.mergingDefaults(from: defaults) ?? defaults
    }
}
