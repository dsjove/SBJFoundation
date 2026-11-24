import SBJLocalization

/// Synthesize an ordinary `SBJNomenclature` whose title is derived at compile
/// time from the enclosing `propertyNameNomenclature` static declaration.
/// Explicit titles continue to use `SBJNomenclature(title: ...)` directly.
/// Works in both `@SBJStructure` types and `@SBJStructureExtension` extensions,
/// as well as enum-case nomenclature declarations.
@freestanding(expression)
public macro SBJAutoNomenclature(
    summary: String? = nil,
    details: String? = nil,
    aliases: [String] = [],
    symbol: SBJSymbol? = nil,
    accessibilityLabel: String? = nil,
    accessibilityHint: String? = nil
) -> SBJNomenclature = #externalMacro(
    module: "SBJStructureMacros", type: "SBJAutoNomenclatureMacro"
)
