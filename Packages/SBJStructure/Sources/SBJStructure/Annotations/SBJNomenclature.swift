import SBJLocalization

/// Marks the single structural extension of a type. Its `nameNomenclature` declarations
/// supply nomenclature; explicitly annotated `@SBJComputed` properties are added
/// to semantic discovery and optionally to automatic editor presentation.
/// The original `@SBJStructure` declaration retains serialization and mutation.
/// Additional ordinary Swift extensions remain unrestricted.
@attached(member, names: named(_extensionNomenclature), named(propertyNomenclature), named(sbjComputedProperties))
public macro SBJStructureExtension() = #externalMacro(
    module: "SBJStructureMacros", type: "SBJStructureExtensionMacro"
)

/// Synthesizes enum-case metadata lookup from `caseNameNomenclature` static members
/// on an extension. Case declarations remain free of metadata annotations.
///
/// A distinct extension marker is needed because an extension macro cannot
/// determine whether the extended type is an enum from extension syntax alone.
@attached(member, names: named(sbjCaseNomenclature))
public macro SBJNomenclatureEnum() = #externalMacro(
    module: "SBJStructureMacros", type: "SBJNomenclatureMacro"
)
