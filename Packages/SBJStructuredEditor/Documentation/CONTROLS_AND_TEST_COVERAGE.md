# Controls and interaction

`SBJValueEditor` dispatches to specialized value editors. Typed unit values are atomic: `UnitValue`, `MixedUnitValue`, and `PairedUnitValue` render through specialized controls and do not expose implementation properties as child editor rows. An optional value displays creation or clearing controls; populated optional collections pass their collection actions to the collection header.

## Collections

Arrays, sets, and dictionaries have distinct insertion rules. Arrays use `SBJEditorRegistry.createArrayElement(_:existing:)` and honor collection-aware exhaustion. Sets with `CaseIterable & Hashable` elements select the first case not already stored, in `allCases` order. Dictionaries with `CaseIterable & Hashable` keys select the first unused key, then create a value through the registry. Both disable insertion when all cases are used. For other types, set elements and dictionary keys retain existing default-construction behavior, rejecting duplicate candidates. A dictionary also disables insertion when its value cannot be constructed. Selection runs through internal registry helpers; rendering controls do not duplicate the rules.

Array remove and move actions resolve the current index when invoked, not when the row was initially drawn; actions targeting a stale element do not mutate an unrelated position. SwiftUI confirmation and disclosure layout remain presentation responsibilities.

## Tests

Existing tests cover array action boundaries and stale rows, registry precedence/exhaustion, finite set and dictionary insertion, collection presentation, associated-case bridges, unit editor type dispatch, flat projections, search expansion, and accessibility. `SBJCollectionAndUnitInteractionTests` adds atomic mixed/paired measurement traversal (including optionals), removal by a changed live index, and out-of-range mutation safety.

## Limitations of automated tests

Pure value and traversal tests do not establish accessibility, visual alignment, focus, keyboard interaction, confirmation prompts, or menu behavior on every Apple platform. These require simulator/device testing. The optional collection add/clear cycle and the three collection types should be covered in UI integration testing. Performance profiling is a separate activity from control behavior verification.

## API

Container creation helpers do not require changes to existing public signatures. Controls remain in StructuredEditor, while ordinary collection mutation and structural metadata remain in DataDefinition.
