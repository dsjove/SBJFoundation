# Domain meaning in SBJLocalization

`SBJLocalization` lets an ordinary Swift type express domain meaning without adopting
SBJStructure. `SBJStructure` may build structure-aware conveniences on top of
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

Structural equivalence compares complete logical stored values, not whether two
objects look the same to a user. It does not compare raw Swift allocation bytes,
addresses, padding, capacity or hash-table order. Implementations should include
private stored state and should not evaluate computed properties merely to compare
objects. Serialization, custom application equality and content semantics are separate.

`SBJStructuralCompare.equals` accepts explicit `SBJStructuralComparable`
conformances only. Unknown types compare unequal (including against themselves);
there is no automatic `Equatable`, Codable or description fallback. A caller
must not interpret a false result as proof of different state if a type lacks a
comparison implementation. Use `SBJStructuralScalar` only for an explicitly audited
opaque type whose `==` compares its entire logical value.

Standard scalar conformances cover Boolean, common integer types, Float, Double,
CGFloat, String, Character, Date, UUID, URL, Data, Duration and Decimal. Float16
is supported on ARM64 and Linux. Floating-point values use their bit patterns and
strings use UTF-8 code units. Foundation values are compared through their public
value representations: Decimal compares numeric value, exponent and sign (NaNs
compare alike); URL compares relative string and base URL; Date compares the
reference-date interval. These are not claims about private Foundation storage.

Optional, Array, Set and Dictionary support structural comparison without Codable
constraints. Arrays preserve order, and unordered collections compare actual
members and key/value pairs, not merely application-defined Hashable identity.
The latter use hash lookup as a fast path, with one-to-one structural matching
when necessary (quadratic in the worst case).

`HasContentCheckable` remains independent: an object may contain stored values
while containing no meaningful information for the user. Existing primitive and
container content policies remain unchanged in this iteration.

## Future direction

Context-sensitive naming and layered vocabularies remain future capabilities;
the existing nomenclature APIs do not provide an automatic localized resolver.
