# Phase 2 — Structure metadata and annotation contracts

The structural `@SBJStructure` declaration generates coded-property descriptors, writable-property descriptors, and `_propertyInfo(for:)` for metadata declared **inside** the type. Metadata in a separate extension must use `@SBJPropertyInfo` to generate the public `propertyInfo(for:)` dispatch and `_extensionPropertyInfo(for:)` fallback. If an extension defines a custom static `propertyInfo(for:)`, it should call `_extensionPropertyInfo(for:)` for properties it does not override.

`@SBJPropertyInfoEnum` is a separate extension annotation for enum-case documentation. Enum cases are not key-path targets; use `sbjCaseInfo(for:)`. Plain enums do not automatically conform to `SBJStructuredEnum`.

`@SBJDesignatedInit` records the initializer's argument order, external labels, defaults, and simple direct self-property assignments in `sbjSwiftInitializerParameters`. The current representation is intended for Swift-source construction, not default-value synthesis; broader synthesis and the fallback encoder are Phase 3. Complex expressions assigned to stored properties are not inferred as parameter mappings.

## Regression checks

- Extension-provided property information appears in `propertyInfo(for:)` and `sbjProperties[].info`.
- Custom public metadata lookup can override selected properties and forward all others.
- Enum extension metadata resolves by case name and returns nil for unknown cases.
- Designated initializer metadata handles argument labels, defaults, and multiline direct assignments.

These tests must be run with the package's specified Swift 6.4 toolchain and Apple platform SDKs.
