import SBJLocalization

/// Contributes nomenclature and discoverable computed properties from one structural extension.
@attached(member, names: named(_extensionNomenclature), named(propertyNomenclature), named(sbjProperties))
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
