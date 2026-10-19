# Units

SBJFoundation owns reusable physical-unit semantics. They exist to be codable
and be extended for presentation and editability.
This is deliberately part of the pre-localization architecture because unit presentation depends on locale,
domain policy, abbreviations, number formatting, and eventually available space.

## Core types

- `UnitType` describes a strongly typed unit backed by Foundation `Dimension`.
- `UnitValue<Unit>` is the Codable amount + unit value.
- `LengthUnit`, `MassUnit`, `VolumeUnit`, and `DurationUnit` provide common units.
- `MeasurementSystem` is classification only; it does not dictate formatting.
- `UnitEditingPolicy` keeps step increments out of unit identity.

`UnitValue` preserves source units at rest. `converted(to:)` is explicit,
non-mutating, and delegates conversion math to Foundation `Measurement`.

The decoder accepts the former Character `Quantity` key `kind`; new encoding
uses `unit`. `Quantity` remains a source-compatibility typealias for now.

## UI

`UnitValueControl` is the reusable UIVocabulary control for a numeric amount and
unit presentation. With multiple allowed units it provides a picker; with one
allowed unit it presents that unit as fixed vocabulary. Changing a selectable unit
converts the amount so the represented physical quantity is preserved.
The caller supplies an allowed-unit list when domain policy is narrower than the
unit type's full case set; SBJFoundation does not decide which units a game, recipe,
or document should permit.

SBJStructure recognizes `UnitValue` as a stock typed leaf editor. The structured
editor preview contains length, mass, volume, and optional unit-value examples.

## Package ownership

- SBJFoundation: unit identity, conversion, Codable values, editing policy, the
  generic unit-value control/editor, and the reusable unit-conversion model/screens.
- Applications: allowed units, preferred units, recipe/game-specific increments,
  and domain presentation policy.
- SBJLayout: keeps PDF/Core Graphics storage in points but uses `UnitValue` for
  physical conversion at its public/editor boundary. Page-layout margin editing
  uses the shared `UnitValueControl` with inches or millimeters fixed by page family.

## Localization boundary

`UnitType.displayName` is intentionally documented as temporary pre-localization
vocabulary. It should be replaced by the shared presentation-resource design;
unit names and symbols must not become a parallel localization subsystem.
