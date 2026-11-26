# SBJStructuredAI

Read-only assistant for structured documents. The public factory is `SBJAIAvailability.makeAssistant(snapshot:domainInstructions:diagnostic:displayError:)`; the host stores `any SBJAssistantCoordinating & SBJAssistantPresenting`. The public UI and host boundary are unchanged.

## Architecture

[Architectural rules](ARCHITECTURE.md) defines the required model communication, exact-key resolution, validation, and mutation boundaries for all contributors. Consult it before modifying tools or model-facing representations.

## Structural context

Milestone 1.3 builds the complete structural definition from declared types through `SBJStructuralTraversal.definition(of:)` and `SBJStructuralType.container(of:)`. The model sees each collection's declared element structure once, regardless of its membership. Empty collections and absent optionals retain their declared shape. Associated enum payloads are unioned by name and exact declared type; read paths retain case membership and reject inactive payloads. The enum itself can be read to discover the active case. Scalar enum choices are available through metadata. The compact notation uses + structure, | array, : dictionary, * set, - leaf, with ? prefixing optional types; repeated compound types share templates, and distinct types share a template when their compressed child definitions (labels, markers and shape) are identical; occurrence IDs are excluded from equivalence; collection wrappers use their compound element type for eligibility; leaves and atomic values are never eligible; nested template references are allowed; templates declare shared member IDs once; occurrence references contain only the template number; root-relative key paths resolve shared IDs; closing braces terminate the final child without a semicolon; no instance values, names, counts or optional presence are injected. Empty nonoptional object branches are omitted. Recursive type graphs are reported as unsupported rather than silently truncated. Repeated definition sites receive a template; nested children only used once in the consolidated graph remain inline. Native token counts are measured separately. Shared declaration IDs retain all original occurrence paths and property-specific rules; key-path reads and descriptions resolve the appropriate occurrence.

Static declaration IDs are assigned once, after template consolidation. Runtime nodes have no allocated instance IDs. A complete path identifies an occurrence. The complete definition is measured before session installation; excess context is reported without truncation. Native model token counts are not available on Linux.

## Read tools

The session registers two native Foundation Models tools, using compile-time `@Generable` arguments (`keyPath: [String]`) and native `String` results described by EBNF:

- `readValue(keyPath:)`: reads one requested value.
- `readKeys(keyPath:)`: returns the current member keys of one collection, using `key=title` when a selectable key differs from its title.

`readDescription` remains implemented but is not registered for this milestone. No collection index is sent with prompts. The model obtains only relevant names on demand.

Paths start at the implicit root. Use immediate numeric declaration IDs as strings, exact member keys, or one-based `@n` array positions. For `@2{10-Amount}` and `20+Current#2`, use `["20","10"]`. Template numbers are not keys. Duplicate array names and ordinal-shaped names use ordinals. Dictionaries prefer their key; unique titles can also resolve them. Unaddressable unordered duplicates are reported. No global instance IDs or scope are required.

If a read encounters a missing or ambiguous member selector, it returns `memberRequired:insert:3;keys:Pebble,Granite` (or `replace`), where the position is one-based. Actual numeric member names take precedence over missing-field inference. No member is selected automatically. Results are bounded by the existing native per-result token budget (up to 384 tokens); oversized lists are reported rather than silently truncated. Pagination is not exposed yet.

The semantic query API returns a typed `SBJSemanticReadResult`; no response dictionaries or manual JSON encoding are used. Document data and description metadata still use `SBJSemanticValue` for their variable shape. Model-facing outputs are `value:24`, `keys:Strength,Dexterity`, `memberRequired:insert:3;keys:Pebble,Granite`, `status:unset`, or `error:"Invalid key"`. Quoted strings escape delimiters and controls. The response grammar lives beside the renderer. Atomic values are leaves. Optional absence, inactive union cases, empty content and invalid paths remain distinct. The static grammar and templates remain unchanged.

## Session lifecycle

The coordinator prepares and prewarms the selected session during activation. On context exhaustion it retains the original native instructions and up to two completed transactions, reconstructs and prewarms the native session, then retries once. A document ID or revision change invalidates the snapshot and its declaration catalog. Parallel read calls operate on immutable Sendable data. The visible conversation and UI remain unchanged. Native context measurement is asynchronous and shared between prewarming and the first submission.

## Validation

Core tests exercise structure, identity, metadata, collection reads and absence. Native tests exercise actual generated tool arguments and the emitted EBNF text. Core result tests verify exact numbers, distinct absence states, key negotiation and escaping. Opt-in live tests use `SBJ_RUN_LIVE_QUERY_TESTS=1` or `SBJ_RUN_LIVE_CONTINUITY_TESTS=1`. Apple SDK compilation and live model inference must be verified in Xcode.

Apple references: https://developer.apple.com/documentation/foundationmodels/tool ; https://developer.apple.com/documentation/foundationmodels/managing-the-context-window ; https://developer.apple.com/documentation/foundationmodels/optimizing-key-value-caching-in-language-model-sessions
