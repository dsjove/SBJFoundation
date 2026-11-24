# Domain meaning in SBJLocalization

`SBJLocalization` lets an ordinary Swift type express domain meaning without adopting
SBJStructure. `SBJDataDefinition` may build structure-aware conveniences on top of
these contracts, but is not required to use them.

## Naming

Adopt `SBJNomenclatureProviding` to provide a default `SBJNomenclature` for a type.
Use `SBJNomenclatureResolver.resolve(_:for:)` to overlay property-specific nomenclature
onto those defaults. Property metadata takes precedence independently per attribute.

## Meaningful content and invariants

Adopt `HasContentCheckable` when `isEmpty` or equality with zero does not describe
whether an instance contains meaningful information. Implement `invariant(at:)` when
that value has validation requirements. `SBJValidationKeyPath` supplies validation
locations, and `SBJValidationError` reports a failure.

## Independent structural comparison

Adopt `SBJStructuralComparable` when an application's `==` semantics differ from
structural equivalence. `SBJStructuralCompare.equals` dispatches explicit structural
comparisons before considering `Equatable` and encoded fallback values.

## Future direction

Context-sensitive naming and layered vocabularies remain future capabilities;
the existing nomenclature APIs do not provide an automatic localized resolver.
