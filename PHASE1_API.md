# Phase 1: API preparation, no implementation extraction

| Data definition | Editor-specific | Change |
|---|---|---|
| `SBJStructure` | editor synthesis retained until extraction | static `_propertyInfo(for:)` convention |
| `SBJString(minLength:maxLength:trimming:)` | `SBJEditorString(_:autocorrect:capitalization:)` | split |
| `SBJArray(reorderable:minCount:maxCount:unique:uniqueBy:)` | `SBJEditorArray(title:)` | split; order mutation policy is data semantics |
| `SBJSet(minCount:maxCount:)` | `SBJEditorSet(title:)` | split |
| `SBJOptional(required:)` | — | DD |
| `SBJUnitValue(min:)` | — | DD; unit immutable; fixed-unit editing |
| `SBJInteger`, `SBJNumber`, `SBJDate`, `SBJData`, `SBJURL`, `SBJUUID`, `SBJColor`, `SBJDictionary`, `SBJDesignatedInit` | — | DD |
| — | `SBJEditorDisclosure`, `SBJEditorExclude`, `SBJEditorProperty` | editor-only |
| — | `SBJEditorFontFamily` | replaces removed `SBJPresentation` |

`SBJPropertyInfo.details` is optional. For new model declarations, `static let fooInfo = SBJPropertyInfo(...)` is detected inside the annotated struct. The generated static `_propertyInfo(for:)` can be called from explicit static `propertyInfo(for:)` overrides. Existing handwritten overrides remain supported. Declarations in separate extensions are not visible to the type's member macro, so automatic discovery requires declarations inside the annotated type.

`SBJDataDefinition` and `SBJStructuredEditor` targets are intentionally empty scaffolds. Editor and UIVocabulary dependency analysis and implementation extraction are later phases.
