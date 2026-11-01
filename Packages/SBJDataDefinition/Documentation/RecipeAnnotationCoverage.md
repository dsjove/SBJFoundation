# Recipe integration coverage

The Recipe sample is a representative integration fixture, not an exhaustive permutation test.

## Annotated in Recipe

- Structural macros: `@SBJStructure` (structs and associated-value enums), `@SBJPropertyInfo`, `@SBJPropertyInfoEnum`, `@SBJDesignatedInit`.
- Validation: `@SBJString`, `@SBJInteger`, `@SBJNumber`, `@SBJOptional`, `@SBJArray`, `@SBJSet`, `@SBJDictionary`, `@SBJDate`, `@SBJURL`, `@SBJUUID`, `@SBJData`, `@SBJUnitValue`.
- Presentation: `@SBJStringPresentation`, `@SBJArrayPresentation`, `@SBJSetPresentation`, `@SBJColorPresentation`, `@SBJFieldPresentation`.
- Reusable metadata: `SBJStructureSampleCourse.definitionTypeInfo`, property-specific `courseInfo` summary, inherited default metadata for `optionalCourse`.

## Dedicated-fixture coverage / not directly demonstrated in Recipe

- Full combinations of every rule parameter, including edge-case constraints, require focused rule tests.
- `@SBJDictionaryPresentation` and some specialized presentation annotations are not on the Recipe properties; maintain explicit dedicated tests if these APIs are supported.
- The non-Recipe `SBJDefinitionTypeInfoTests` cover absence of defaults, explicit attribute merges, and optional wrappers.

## Keep in sync

`SBJRecipeAnnotationCoverageTests` asserts actual metadata for representative property rules and presentation hints, and checks the new type-default/override scenario. This document is an inventory, not a machine-enforced guarantee of 100% annotation API coverage.
