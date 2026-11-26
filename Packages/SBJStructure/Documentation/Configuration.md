# Annotation configuration and contracts

How structural annotations configure validation rules, presentation hints, and model metadata. Current limitations are noted where relevant to clients.

## Configuration values used by generated metadata

- Rules: `SBJStringRules`, `SBJIntegerRules`, `SBJNumberRules`, `SBJOptionalRules`, `SBJArrayRules`, `SBJSetRules`, `SBJDictionaryRules`, `SBJDataRules`, `SBJUUIDRules`, `SBJDateRules`, `SBJURLRules`.
- Presentation: `SBJFieldPresentationValue`, `SBJStringPresentationValue`, `SBJUnitValuePresentationValue`, `SBJColorPresentationValue`.
- Rule metadata remains descriptive; generated validation is only executed when explicitly invoked.
- The color alpha option is a presentation policy (`@SBJColorPresentation(alpha:)`), not a data rule.

## Intentionally separate metadata and unit design

- Array `unique` and `uniqueBy` remain typed data rules. `reorderable` is a presentation setting in `SBJArrayPresentationValue`. Uniqueness keeps typed Swift key paths in generated validation.
- Collection `elementName` is a shared structural naming hint retaining the compiler-checked key path.
- Unit `unitMutable`, `defaultUnit`, and `unitSystem` remain separate pending unit rule design.
- Do not introduce string identifiers or registration schemes to make these options Codable.

## Contracts and limitations

- Annotation arguments and configuration members should agree in names, defaults, and semantics. Numeric `range`/`min` overloads currently represent exclusive alternatives even though the value struct can represent both; redesign separately.
- `SBJColorPresentationValue` is Codable and Sendable, like other portable values.
- UIVocabulary modifiers use configuration-driven input policies; UI configuration remains an independent client concern.
- Collection constraints, presentation capabilities, and sort configuration are described in [CollectionAnnotations.md](CollectionAnnotations.md). Set/Dictionary editor sorting and compiler checks for presentation sort remain unverified/incomplete.

### Numeric bounds (Iteration 6)

`SBJIntegerRules` and `SBJNumberRules` expose optional `min` and `max` properties. `init(range:)` converts the closed range to these bounds; `init(min:max:)` allows independent bounds. `SBJStringRules` additionally exposes optional `allowedValues` and `pattern`. Dictionary rule names and collection annotation APIs are unchanged.
