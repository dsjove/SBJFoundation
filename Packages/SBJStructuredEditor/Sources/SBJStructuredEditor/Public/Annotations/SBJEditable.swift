import SBJUIVocabulary
import SBJUnits
/// Generates structural metadata and editor integration with one annotation.
///
/// `@SBJEditable` includes all behavior of `@SBJStructure`; do not apply both
/// annotations to the same declaration.
@attached(member,
    names:
        named(_hasContent), named(hasContent),
        named(_invariant), named(invariant),
        named(_sbjStructuralEquals), named(sbjStructuralEquals),
        named(sbjDefaultValue), named(sbjCreateDefaultValueIfPossible),
        named(sbjProperties), named(_propertyInfo),
        named(sbjMutableProperties), named(sbjEditorFields),
        named(sbjEditorEnumCases),
        named(sbjCaseName), named(sbjCaseNames), named(sbjCaseInfo)
)
@attached(extension,
    conformances:
        SBJMutableStructure, SBJSwiftUIEditable,
        SBJEditableAssociatedEnum,
        SBJEnumCaseIdentifiable, SBJStructuredEnum)
public macro SBJEditable() = #externalMacro(
    module: "SBJStructuredEditorMacros",
    type: "SBJEditableMacro"
)
