/// Generates UI-independent structural metadata
/// for a `Codable` structure or enum.
///
/// The macro does not wrap stored properties, intercept reads or writes, or
/// automatically validate assignments. Structural rules are consumed only when
/// validation or another SBJStructure consumer is explicitly invoked.
///
/// For structures, coded stored properties become structural metadata. Stored
/// writable properties also become editor-independent mutable-property descriptors.
/// Editor-specific declarations are generated only by `@SBJEditable`.
/// Immutable `let` properties remain structural but are not mutable.
///
/// Enums receive exact source case names. Payload enums receive structural
/// comparison support; editor case descriptors are exclusive to `@SBJEditable`.
@attached(member,
    names:
        // Business
            named(_hasContent), named(hasContent),
            named(_invariant), named(invariant),
            named(_sbjStructuralEquals), named(sbjStructuralEquals),
            named(sbjDefaultValue),
            named(sbjCreateDefaultValueIfPossible),
            named(sbjProperties), named(_propertyInfo),
            named(sbjMutableProperties),
        // Swift Code Encoder Enum
            named(sbjCaseName),
            named(sbjCaseNames), named(sbjCaseInfo)
)

@attached(extension,
    conformances:
        // Structural type
            SBJMutableStructure,
        // Swift Code Encoder Enum / payload-enum marker
            SBJEnumCaseIdentifiable, SBJStructuredEnum)

public macro SBJStructure() = #externalMacro(
    module: "SBJDataDefinitionMacros",
    type: "SBJStructureMacro"
)
