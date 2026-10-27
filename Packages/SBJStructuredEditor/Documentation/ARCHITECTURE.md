# Editor architecture

## Public boundary

`SBJEditorView`, `SBJStructuralEditorView`, `SBJCodableEditorCore`, `SBJCodableEditor`, `SBJEditorRegistry`, and editor presentation/navigation/search configuration are client-facing. Editor traversal nodes, draft bindings, collection mutation coordinators, and control dispatch are internal implementation responsibilities. Public declaration visibility is not changed solely because a helper resides outside `Editor/Public`.

## Data ownership

DataDefinition defines the structured model: typed properties, annotations, validation, default values, structural search and collection identity. StructuredEditor binds these capabilities to SwiftUI, selects controls, manages transient view state, and resolves live mutations. Application-specific models and their construction policies are not embedded in the editor.

## Construction

A registered exact-type factory overrides the DataDefinition default for ordinary creation. Array insertion first consults `SBJCollectionElementCreatable` when adopted, including intentional `nil` exhaustion. Set insertion first selects an unused `CaseIterable & Hashable` element when supported. Dictionary insertion selects an unused `CaseIterable & Hashable` key and then constructs its value. Other types use defaults with collision checks. Construction decisions are computed in the registry, not duplicated by collection views.

## Binding and traversal

Structural field projections retain typed writable key paths. Editor traversal creates per-row contexts preserving search criteria and navigation ancestry. Collection identity and current index are distinct. Array actions resolve current indices at invocation; sets are edited as drafts and committed atomically to preserve uniqueness. Optional atomic values render directly without exposing structural children.

## Control ownership

`SBJValueEditor` dispatches supported values to specialized editors. Each control owns SwiftUI interaction and layout while leaving model rules in DataDefinition. Unit controls treat single, mixed, and paired measurements as indivisible rows. Disclosure, filtering, removal confirmation and help content are editor presentation behavior.

## Testing boundary

Unit tests protect registry creation, traversal, binding mutation, identity, enum bridging, and specialized value dispatch. SwiftUI focus, keyboard, menu, accessibility and platform layout need integration tests; unit tests alone do not establish those behaviors.
