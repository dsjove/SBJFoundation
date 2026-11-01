# DataDefinition annotation configuration audit

This document describes the currently implemented configuration architecture and explicitly identifies remaining limitations.

## Configuration values used by generated metadata

- Rules: `SBJStringRules`, `SBJIntegerRules`, `SBJNumberRules`, `SBJOptionalRules`, `SBJArrayRules`, `SBJSetRules`, `SBJDictionaryRules`, `SBJDataRules`, `SBJUUIDRules`, `SBJDateRules`, `SBJURLRules`.
- Presentation: `SBJFieldPresentationValue`, `SBJStringPresentationValue`, `SBJUnitValuePresentationValue`, `SBJColorPresentationValue`.
- Rule metadata remains descriptive; generated validation is only executed when explicitly invoked.
- The color alpha option is a presentation policy (`@SBJColorPresentation(alpha:)`), not a data rule.

## Intentionally separate metadata and unit design

- Array `unique` and `uniqueBy` remain typed data rules. `reorderable` is a presentation setting in `SBJArrayPresentationValue`. Uniqueness keeps typed Swift key paths in generated validation.
- Collection `itemTitle` remains a presentation hint derived from a typed key path.
- Unit `unitMutable`, `defaultUnit`, and `unitSystem` remain separate pending unit rule design.
- Do not introduce string identifiers or registration schemes to make these options Codable.

## Configuration contract / unresolved APIs

- Annotation arguments and configuration members should agree in names, defaults, and semantics. Numeric `range`/`min` overloads currently represent exclusive alternatives even though the value struct can represent both; redesign separately.
- `SBJColorPresentationValue` is Codable and Sendable, like other portable values.
- UIVocabulary modifiers use configuration-driven input policies; dependent application migration remains separate work.
- Collection constraints, presentation capabilities, and sort configuration are described in [COLLECTION_ANNOTATIONS.md](COLLECTION_ANNOTATIONS.md). Set/Dictionary editor sorting and compiler checks for presentation sort remain unverified/incomplete.
