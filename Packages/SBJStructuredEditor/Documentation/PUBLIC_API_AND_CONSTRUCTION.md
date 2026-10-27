# StructuredEditor: Public API, construction, and binding

## Package responsibilities

`SBJStructuredEditor` owns SwiftUI editing, editor presentation, user interaction, bindings, and editor-specific creation overrides. `SBJDataDefinition` owns structural metadata, default-value construction, structural traversal, and `SBJCollectionElementCreatable` container-aware creation. The editor consumes these model capabilities without creating model-specific dependencies.

## Client-facing API

- `SBJEditorView`, `SBJCodableEditorCore`, and `SBJCodableEditor` provide editor compositions.
- `SBJEditorRegistry` configures exact-type custom editors and creators, per-property line items, and binding overrides.
- `SBJEditorPresentationModel`, editor options, navigation, and search UI expose host-controlled behavior.

SwiftUI view types and their initializers are public where hosting clients must construct them. Helpers located outside `Editor/Public` may still need public visibility, for example the extensions on `Encodable`, `Decodable`, and `Set`; directory placement alone is not a visibility contract.

## Construction precedence

- `SBJEditorRegistry.create(T.self)` first checks an exact-type registered creator, then delegates to `SBJDefaultValue.value(for:)`.
- `createArrayElement(T.self, existing:)` first delegates to `SBJCollectionElementCreatable` when adopted. A returned `nil` is an intentional refusal (such as exhausted available keys), **not** permission to fall back to arbitrary construction.
- For other element types, the registry uses ordinary `create(T.self)`.
- Registration is exact-type based. It does not apply recursively to optionals or to unrelated concrete generic specializations.

`registerBinding` is a property-specific override based on root type and writable key path. It is intended for cases where editing requires a transformation outside the model property itself. A binding override does not redefine the value's model metadata.

## Public API boundaries and ownership

1. **Preserve the registry entry points.** Each has a distinct purpose and there is no proven redundancy. App-defined creators remain opt-in; basic defaults belong in DataDefinition.
2. **Preserve public visibility for view and registry configuration APIs.** With no app build in scope, narrowing access would be speculative. The internal registration wrappers and lookup methods are already non-public.
3. **Do not move `SBJEditorValueTraversal` into DataDefinition.** Its identity and mutation work use editor binding context, despite leveraging DataDefinition collection metadata.
4. **Codable snapshot helpers:** `sbjCodableCopy()` is called by `SBJEditorView` to capture a baseline; `sbjEncodedIsDifferent(from:)` is currently exercised in tests. Their functions are generic, but relocating or reducing public visibility should be coordinated with the Foundation API ownership review. Keep behavior unchanged for now.
5. **Set replacement:** `sbjReplace(_:with:)` avoids collisions and is used by editor mutation. Its generality alone is not a reason to migrate it without verifying external consumers.
6. **`SBJCodableEditor` wrapper:** Its `title` parameter is accepted but unused. This is a candidate for public API simplification, but removing it is source-breaking and should be explicitly approved.

## Test coverage and limits

Construction tests exercise registered exact-type overrides, ordinary primitive defaults, collection-aware creation, and exhausted collection refusal. Existing package tests cover per-property binding registration, array element creation, structural traversal, and custom editor behavior. UI integration tests should exercise for focus, optional-collection controls, bindings during reordering, and actual removal confirmation.

This document describes the current interface and its explicit boundaries. It does not claim runtime UI or cross-platform performance verification.
