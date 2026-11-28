# SBJStructuredAI

Read/write assistant prototype for structured documents. The public factory is `SBJAIAvailability.makeAssistant(snapshot:domainInstructions:diagnostic:displayError:)`; the host stores `any SBJAssistantCoordinating & SBJAssistantPresenting`. The public UI and host boundary are unchanged.

## Architecture

[Architectural rules](ARCHITECTURE.md) defines the required model communication, exact-key resolution, and validation boundaries for all contributors. Consult it before modifying tools or model-facing representations.

The single source for library-authored model instructions, lexical/structural/response grammars, tool names, descriptions, argument guides and error prose is [`SBJAIInstructions.swift`](Sources/SBJStructuredAI/Core/SBJAIInstructions.swift). The host alone supplies conversational behavior and domain instructions; the library supplies only document navigation and tool protocol instructions. Document labels and runtime values are data, not hardcoded instructions.

## Structural context

The library builds the complete structural definition from declared types through `SBJStructuralTraversal.definition(of:)` and `SBJStructuralType.container(of:)`. The model sees each collection's declared element structure once, regardless of its membership. Empty collections and absent optionals retain their declared shape. Associated enum payloads are unioned by name and exact declared type; read paths retain case membership and reject inactive payloads. The enum itself can be read to discover the active case. Scalar enum choices are available through metadata. The compact notation uses + structure, | array, : dictionary, * set, - leaf, with ? prefixing optional types; repeated compound types share templates, and distinct types share a template when their compressed child definitions (labels, markers and shape) are identical; occurrence IDs are excluded from equivalence; collection wrappers use their compound element type for eligibility; leaves and atomic values are never eligible; nested template references are allowed; templates declare shared member IDs once; occurrence references contain only the template number; root-relative key paths resolve shared IDs; the root precedes newline-separated template definitions; titles and aliases precede the numeric ID and kind; semicolons separate all siblings, including branches; no instance values, names, counts or optional presence are injected. Empty nonoptional object branches are omitted. Recursive type graphs are reported as unsupported rather than silently truncated. Repeated definition sites receive a template; nested children only used once in the consolidated graph remain inline. Native token counts are measured separately. Shared declaration IDs retain all original occurrence paths and property-specific rules; key-path reads and descriptions resolve the appropriate occurrence.

Static declaration IDs are assigned once, after template consolidation. Runtime nodes have no allocated instance IDs. A complete path identifies an occurrence. The complete definition is measured before session installation; excess context is reported without truncation. Native model token counts are not available on Linux.

## Read tools

Every session registers three read-only native Foundation Models tools, using compile-time `@Generable` arguments (`keyPath: [String]`) and native `String` results described by EBNF:

- `readValue(keyPath:)`: reads one requested value.
- `readKeys(keyPath:)`: returns the current member keys of one collection, using `key=title` when a selectable key differs from its title.
- `readDescription(keyPath:)`: reads declared field metadata, constraints and choices.

No collection index is sent with prompts. The model obtains only relevant names on demand.

Paths start at the implicit root. Use immediate numeric declaration IDs as strings, exact member keys, or one-based `@n` array positions. For `@2{Amount:10-}` and `Current:20+#2`, use `["20","10"]`. Template numbers are not keys. Duplicate array names and ordinal-shaped names use ordinals. Dictionaries prefer their key; unique titles can also resolve them. Unaddressable unordered duplicates are reported. No global instance IDs or scope are required. The model resolves equally matching static fields by lowest numeric field ID, then by the first numerically smaller ancestor path when shared IDs tie. Explicit context takes precedence. This rule does not resolve duplicate collection names; the model must select a supplied member key.

If a read encounters a missing or ambiguous member selector, it returns `memberRequired:insert:3;keys:Alpha,Beta` (or `replace`), where the position is one-based. Actual numeric member names take precedence over missing-field inference. No member is selected automatically. Results are bounded by the existing native per-result token budget (up to 384 tokens); oversized lists are reported rather than silently truncated. Pagination is not exposed yet.

The semantic query API returns a typed `SBJSemanticReadResult`; no response dictionaries or manual JSON encoding are used. Document data and description metadata still use `SBJSemanticValue` for their variable shape. Model-facing outputs are `value:24`, `keys:Alpha,Beta`, `memberRequired:insert:3;keys:Alpha,Beta`, `status:unset`, or `error:"Invalid key"`. Quoted strings escape delimiters and controls. The response grammar and all library-authored model instructions live in `SBJAIInstructions.swift`. Atomic values are leaves. Optional absence, inactive union cases, empty content and invalid paths remain distinct. Template identity and declaration IDs are independent of the rendered notation.

## Leaf mutation

Editable documents with a mutable structural root and the optional `persist` factory callback also register `mutateValue(keyPath:value:)`. It uses the same key path as `readValue` and native `@Generable` arguments. Swift resolves the location and converts the supplied text to the existing Swift leaf type. Supported values include strings, booleans, numeric primitives, Decimal, dates, UUIDs, unambiguous CaseIterable enum choices, existing optional scalar contents, and finite measurement amounts in their existing unit. It does not create absent optional contents, change dictionary keys, change measurement units, construct opaque values, or mutate associated enum payloads unsupported by the structural replacement API.

The checked candidate is validated and presented using the existing transaction and approval panel. The tool suspends while the user reviews it, and returns `status:applied` only after the host persistence callback succeeds, `status:rejected` on rejection, or a deterministic error. Only one staged mutation is allowed per turn. All subsequent tool calls in that turn are refused, preventing stale reads or duplicate proposals. The existing snapshot is discarded after a successful edit. No mutation request that reached approval is automatically replayed on model context exhaustion. Hosts without persistence remain read-only.

## Collection mutation

Editable sessions also register `mutateCollection(keyPath:operation:member:position:value:)`. Use the collection's ordinary read path, an exact `readKeys` member selector for existing elements, and a one-based insertion or final move position. `count` returns `value:n` without approval (0 or 1 for optionals); `countMembers` counts collection contents, including a present optional collection. Read-only sessions continue to register only the three read tools to conserve context.

| Collection | Operations |
| --- | --- |
| Array | add, insert, remove, replace, move, duplicate, clear, count |
| Dictionary | add/insert (new typed key), replace/remove (resolved existing key), put (explicit upsert), clear, count |
| Set | add, remove, replace, clear, count |
| Optional | set, clearOptional, count; ordinary collection verbs target present wrapped collections |

Omit `value` to use the existing collection element factory or default initialization. For dictionaries the same generic factory receives the existing values. Explicit `set` can initialize an empty standard collection in an absent optional wrapper; `clearOptional` removes the wrapper value. No generated JSON objects are accepted. Supply scalar text for scalar members, then use `mutateValue` in subsequent turns to edit fields of default-created structured members. Each edit is independently approved; use `readKeys` again after a creation or reorder. Duplicate member names are never guessed. All write operations build a typed replacement through `SBJStructuralCollectionMutation` and stage it through the same invariant, approval and persistence path as leaf mutation. The approval view shows old and new contents in a scrollable area. The context cost of the new tool must be measured on Apple hardware.

## Session lifecycle

The reset control is opt-in: `SBJAssistantViewOptions(hasResetButton: true)`. It uses a destructive confirmation alert before calling the existing `startNewSession()` presentation API. Cancellation leaves the draft, conversation and pending proposal intact. Confirmation clears the draft, speech state, feedback and previous session, and cancels outstanding inference and unapproved proposals. The coordinator may immediately prewarm a fresh session. The control is disabled during host persistence; previously committed changes are not undone. All presentation strings use the assistant nomenclature set.

The coordinator prepares and prewarms the selected session during activation. On context exhaustion it retains the original native instructions and up to two completed transactions, reconstructs and prewarms the native session, then retries once. Diagnostics preserve the failed transcript before recovery and the latest native transcript; failed transactions are not replayed. A document ID or revision change invalidates the snapshot and its declaration catalog. Parallel read calls operate on immutable Sendable data. The visible conversation and UI remain unchanged. Native context measurement is asynchronous and shared between prewarming and the first submission.

## Validation

Core tests exercise structure, identity, metadata, collection reads and absence. Native tests exercise actual generated tool arguments and the emitted EBNF text. Core result tests verify exact numbers, distinct absence states, key negotiation and escaping. Opt-in live tests use `SBJ_RUN_LIVE_QUERY_TESTS=1` or `SBJ_RUN_LIVE_CONTINUITY_TESTS=1`. Apple SDK compilation and live model inference must be verified in Xcode.

Apple references: https://developer.apple.com/documentation/foundationmodels/tool ; https://developer.apple.com/documentation/foundationmodels/managing-the-context-window ; https://developer.apple.com/documentation/foundationmodels/optimizing-key-value-caching-in-language-model-sessions

### Content-based member selection

At a collection step, `where content has:text` performs a case-insensitive substring match and `where content is:text` performs a case-sensitive exact match over exposed scalar leaf labels (dictionary values, not keys). Empty and ambiguous selectors do not resolve. All read tools and both mutation tools share the resolver. `literal:` escapes a real key starting with a reserved selector prefix; `readKeys` emits the escaped key. Supply raw new keys for dictionary add/put. Unnamed arrays retain one-based `@n` addresses; scalar sets retain value keys. A synthetic optional `name` exists only for explicitly configured compound members without a real `name` property.

### Structural traversal configuration

`SBJAIAvailability.makeAssistant(..., domainInstructions: ..., traversalOptions: ...)`
accepts `SBJTraversalOptions` independently of `SBJAssistantViewOptions`.
The default is `.all` (all discoverable user-facing stored and computed properties).
The selected options apply to both the static definition and instance snapshot,
including mutation resolution. For example, `.all.subtracting(.computed)`
restricts exposed fields to stored state. Compact field identifiers are scoped
to the generated definition; underlying declaration locations retain their ordinals.

## Interactive playground

Open `Playgrounds/SBJAssistant.xcworkspace` and run the macOS recipe playground using the Debug package scheme. See [playground setup and smoke tests](Playgrounds/README.md). The playground uses the public assistant factory and standard assistant view with an in-memory revision-aware document; no library target changes are required.

### Prototype persistence contract

The host supplies value-semantic snapshots, checks document identity and expected revision atomically when persisting, and delivers the completion callback. Once handed to the host, an approved persistence operation cannot be undone by assistant cancellation. Only one mutation attempt is permitted per turn; after staging a proposal, further tool calls are blocked for that turn, including after rejection. This conservative prototype behavior is intentional. Dictionary key generation for the visual editor does not change the existing AI mutation tools.
