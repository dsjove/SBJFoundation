/// Generates structural metadata for accessible stored and computed properties.
/// Codable is independent. Stored-state comparison includes private and excluded state.
/// No storage, property wrappers or accessors are generated.
@attached(member,
    names:
        // Business
            named(_hasContent), named(hasContent),
            named(_invariant), named(invariant),
            named(_sbjStructuralEquals), named(sbjStructuralEquals),
            named(sbjDefaultValue), named(sbjSwiftInitializerParameters),
            named(sbjSwiftWritablePropertyNames),
            named(sbjCreateDefaultValueIfPossible),
            named(_sbjDeclaredProperties), named(_nomenclature),
            named(sbjHasCompleteStoredDefinition), named(sbjReferencedContentOccurrences),
        // Swift Code Encoder Enum
            named(sbjCaseName),
            named(sbjCaseNames), named(sbjCaseNomenclature), named(sbjAssociatedCases)
)

@attached(extension,
    conformances:
        // Structural type
            SBJMutableStructure,
            SBJDefaultValueCreatable,
        // Swift Code Encoder Enum / payload-enum marker
            SBJEnumCaseIdentifiable, SBJStructuredEnum, SBJStructuralComparable)

public macro SBJStructure() = #externalMacro(
    module: "SBJStructureMacros",
    type: "SBJStructureMacro"
)
