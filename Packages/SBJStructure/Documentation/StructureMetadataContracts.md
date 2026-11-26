# Structure metadata and annotation contracts

The structural `@SBJStructure` declaration generates a canonical definition of accessible stored and computed properties and `_nomenclature(for:)` for metadata declared inside the type. Codable is not a prerequisite. `@SBJStructureExtension` contributes accessible computed members to the same definition and generates the public `propertyNomenclature(for:)` dispatch and `_extensionNomenclature(for:)` fallback. If an extension defines a custom static `propertyNomenclature(for:)`, it should call `_extensionNomenclature(for:)` for properties it does not override. `SBJMutableProperty` is a typed writable capability derived from `SBJPropertyMetadata`, not a separate declaration catalog.

`@SBJNomenclatureEnum` is a separate extension annotation for enum-case documentation. Enum cases are not key-path targets; use `sbjCaseNomenclature(for:)`. Plain enums do not automatically conform to `SBJStructuredEnum`.

`@SBJDesignatedInit` records the initializer's argument order, external labels, defaults, and simple direct self-property assignments in `sbjSwiftInitializerParameters`. The current representation is intended for Swift-source construction, not default-value synthesis; broader synthesis and the fallback encoder are separate work. Complex expressions assigned to stored properties are not inferred as parameter mappings.

## Regression checks

- Extension-provided property information appears in `propertyNomenclature(for:)` and `sbjProperties[].info`.
- Custom public metadata lookup can override selected properties and forward all others.
- Enum extension metadata resolves by case name and returns nil for unknown cases.
- Designated initializer metadata handles argument labels, defaults, and multiline direct assignments.

These tests must be run with the package's specified Swift 6.4 toolchain and Apple platform SDKs.

## Atomic structural values

`@SBJStructure(atomic: true)` declares `SBJAtomicStructuralValue` conformance. The type supplies `SBJTextPresentable.presentedValue` for the complete business value. `SBJStructuralType.isAtomic(_:)` is the type-level consumer query. The canonical definition, stored state, validation, construction and Swift export remain unchanged. User-facing descendant traversal and search stop at the atomic boundary. UnitValue, MixedUnitValue and PairedUnitValue are atomic; UnitEditingPolicy remains compound because its independent settings are meaningful members.

Collection nomenclature is independent of structural properties. `SBJCollectionItemIdentification.hasDeclaredName(_:)` checks for an actual user-facing `name` property regardless of content; `declaredName(for:)` reads its current usable text. A configured title takes precedence for collection presentation, followed by a declared name, then the existing fallback. No synthetic name or description is added to the canonical structure.

`SBJStructuralType.optionalPresence(of:)` distinguishes non-optionals, unset optionals and set optionals, even when the wrapped value is empty or itself an unset optional. The existing optional collection operation implementation continues to enforce cardinality zero or one. Inactive union cases and invalid addresses are resolution outcomes, not optional states.
