# Structural Value Operations — Initial Implementation and Coverage Ledger

This document distinguishes **implemented operations** from **proposed operations**. A descriptive operation is not permission to mutate a value; the model's writable flag, visibility policy, concrete type, and whole-model invariants remain authoritative.

## Implemented now

| Resolved Swift value | Operations |
|---|---|
| `Bool` | `assign`, `toggle` |
| `String` | `assign`, `appendText`, `prependText`, `removeText`, `replaceText` (literal matching) |
| `Int`, `Int8`, `Int16`, `Int32`, `Int64` | `assign`, `increase`, `decrease`, `multiply`, `divide` (overflow checked; division truncates toward zero) |
| `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64` | Same (including unsigned-underflow checks) |
| `Float`, `Double`, `CGFloat` | Same (nonfinite operands/results rejected) |
| `Date` | `assign`, `advanceDate` (signed seconds, checked finite) |
| `Array`, `Set`, `Dictionary`, `Optional` | Existing `SBJStructuralCollectionMutation` operations remain authoritative |

`SBJStructuralValueMutation.supportedOperations(for:)` returns **only** executable value operations. Collection capabilities remain separately discoverable through `SBJStructuralCollectionMutation.supportedOperations(for:)`. To apply a value operation, provide an already typed operand and the concrete field value. No JSON reconstruction or language-model arithmetic occurs inside the value engine. Operation nomenclature (`SBJValueOperationNomenclature`) provides descriptions and synonyms; aliases are deliberately not unique across operation types.

## Design coverage — not implemented yet

The following are the reasonable operations planned for remaining structural/value kinds. They are **not** advertised as executable by the first-stage runtime.

| Field kind | Planned operations and constraints |
|---|---|
| `Decimal` and other precision-specific numeric values | Set, checked arithmetic; define precision/rounding and overflow semantics first |
| `Optional<Wrapped>` | Set/create and clear via existing collection engine; forward compatible wrapped operations when present; construction must use typed model defaults |
| `Array<Element>` | Append, insert, remove, replace, move, duplicate, clear, edit element members; preserve indices and identity rules |
| `Set<Element>` | Insert, remove, replace, clear; no positional operation; reject collisions |
| `Dictionary<Key, Value>` | Insert, update, remove, clear, edit members; define safe key rename as collision-checked remove+insert |
| Structured model (`SBJStructured`) | Replace a writable member, mutate nested members, construct an allowed new instance; never invent a whole model from untyped prose |
| Enum / cases with payloads | Choose constructible case; edit existing associated values via supported structural metadata |
| `URL` | Set; optional can clear; component edits only with explicit and validated semantics |
| `UUID` | Set/generate (generation must be an explicit operation), optional can clear |
| `Data` | Replace, append bytes, delete an explicit byte range; require bytes or an explicit encoding |
| `CodableColor` | Set and component adjustments; define color-space and clamping semantics before supporting lighten/darken |
| `CodableFont` | Set family/size/weight/traits where represented by the concrete model |
| `Duration` | Set, increment/decrement, scale with checked conversions |
| `UnitValue` / measurement values | Set, increase/decrease, scale, convert units; enforce dimension compatibility and fixed-unit policy |
| Other conforming custom types | Explicit typed adapters with publicly reported capabilities, never inferred from an `Any` name |

## Transaction and security boundaries

1. Discovery resolves the actual field before interpreting an ambiguous verb. "Add 200 gold" on an `Int` means numeric `increase`, while "add a spell" on an array means `append` or `insert`.
2. AI only proposes a typed operation and operand. It never changes the stored model directly.
3. The semantic processor computes the candidate replacement. The application must request approval through its existing flow.
4. At commit, the writer re-resolves the field, checks writable/visible policy, capabilities, expected old value, concrete type, and full-document invariants before replacing the copy and committing it.
5. Values that require application-specific semantics must decline the operation until a deterministic rule is available. In particular, HP healing does not imply a maximum cap unless domain constraints define one.
6. This milestone introduces `prepareValueChange`, but **does not yet add a Foundation Models tool to invoke it**. The natural-language classifier merely stops forcing ambiguous `add`/`remove` requests into collection-only tooling. End-to-end conversational numeric adjustment is therefore unfinished.

## Next integration milestone

Add explicit scalar-operation tools to `SBJStructuredAI` (with the real field reference and typed operand parsing), teach the AI tool descriptions to choose by resolved capabilities, and extend `SBJStructure` adapters to the remaining types only after their deterministic semantics are specified. Keep the existing revision and user-approval contract intact.
