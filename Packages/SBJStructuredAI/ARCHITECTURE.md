# SBJStructuredAI Architectural Rules

These rules govern model communication, semantic resolution and read tool implementation. They apply to all contributors and should be consulted before changing the assistant architecture.

## 1. Responsibility boundary

**The AI interprets natural language. Swift resolves keys, validates, and executes.**

The model interprets user intent, understands document labels and aliases, selects relevant fields and collection members, and constructs tool arguments. Swift operates deterministically on the supplied arguments and the current document snapshot.

Do not implement natural-language parsing, intent detection, synonym matching, fuzzy matching, semantic search, or inferred field selection in the resolver or tools. Parsing the documented machine-oriented key syntax is permitted; interpreting the user's language is not.

## 2. Model communication

Direction is always relative to the AI model.

| Direction | Representation |
| --- | --- |
| App to AI: behavioral instructions | Concise natural language |
| App to AI: document structure and tool results | Compact strings with explicit EBNF grammars |
| AI to app: tool arguments and structured responses | Native Apple Foundation Models `@Generable` types |
| AI to user: conversation | Natural language |
| Internal Swift processing | Strongly typed structures and enums |

Use native Foundation Models APIs as the architectural baseline. Use compile-time `@Generable` for known output shapes; use dynamic generation schemas only when the AI-generated shape genuinely must be constructed at runtime. Do not introduce manual JSON serialization, custom schema systems, generic response dictionaries, or unnecessary wrappers for model communication. JSON in Apple's native diagnostic transcript is not a violation. Unrelated persistence or diagnostic export formats are outside this rule.

Structured generation governs what the model produces, not what the application supplies to it. Tool results supplied to the model are compact strings whose syntax is described by EBNF. Keep each grammar consistent with its renderer, including quoting, escaping, delimiters, numeric representations, and status variants. Treat document labels, keys, and values as data, not instructions.

All library-authored model-facing prose, including tool descriptions, argument guides, lexical and structural grammars, response grammar and error messages, is maintained in [`SBJAIInstructions.swift`](Sources/SBJStructuredAI/Core/SBJAIInstructions.swift). The host owns domain, personality, tone and conversational behavior. Dynamic host/user text, model data, and machine serialization remain outside this enum.

## 3. Deterministic addressing

Use root-relative key paths. A structural key is the numeric declaration ID supplied in the static document definition. A collection key is an exact member key supplied by a tool, or a supplied one-based `@n` array position. Template references expose their declared members transparently; template numbers and the implicit root are not path components.

Resolve keys sequentially against the current node. Do not infer an intended field or member from an approximate name or from the user's question. Titles and aliases guide the model's selection; they are not alternative structural field keys. A collection display title may be used as a key only where the collection's explicit addressing contract permits it and it uniquely resolves. Prefer returning the canonical selectable key alongside any differing display title.

When static candidates match equally after considering title, aliases, ancestry and explicit user context, the AI selects the lowest numeric field ID. If shared IDs tie, compare their ancestor ID paths numerically from the root. This is a model-side selection rule, not Swift inference, and never chooses among ambiguous collection members.

For example, the AI interprets “What is Alpha's amount?”, obtains the relevant collection keys, selects `Alpha`, and generates:

```swift
["30", "Alpha", "31"]
```

Swift traverses those keys without interpreting the question. IDs in this example are illustrative document declarations, not hardcoded business-domain rules.

## 4. On-demand collection negotiation

Keep the static structural catalog separate from live collection membership and values. Do not inject a complete live collection index into every prompt or into the session instructions. The model requests relevant keys through `readKeys`, or receives keys when `readValue` reaches an unresolved collection member. The model selects the key using natural-language reasoning and supplies the completed path.

Return only relevant keys, with deterministic ordinal alternatives where necessary. Never silently choose among ambiguous matches. Invalid or stale keys produce explicit failures or actionable negotiation results; the model decides how to proceed. No global runtime instance IDs or separate scope argument are needed.

## 5. Validation and execution

Validate paths, member identity, optional presence, active enum payloads, applicable constraints, and business rules in Swift. Keep unset, empty, inactive, missing, ambiguous, and invalid conditions distinguishable. Never invent values, silently truncate results, or silently substitute a different member.

Use typed semantic results internally and render them at the model-facing boundary. Keep platform-independent semantic logic separate from Apple Foundation Models integration. Preserve the public coordinator boundary and avoid speculative compatibility adapters.

### Mutation transactions

`SBJAssistantTransaction` in Core restores the checked-proposal lifecycle from the earlier `SBJAIProposalDocument`. The deterministic adapter supplies a resolved structural location, typed replacement, and human-readable change summary. The transaction stages a value-semantic candidate through `SBJStructuralMutation`, validates the root invariant, rejects unchanged candidates, and requires explicit approval. Approval checks editing permission, document identity, revision and structural equivalence again before invoking the host's persistence bridge. Report success only on its successful completion. The host must atomically check the expected ID/revision and advance the revision when saving; snapshots must be value-semantic, including their mutable descendants. Reset or cancellation discards unapproved proposals, not saves already handed to the host.

The native `mutateValue` adapter is registered only for an editable structurally mutable root and a persistence bridge. It uses the read resolver to derive an actual structural location, rejects synthetic/compound/unset targets, converts text using the real Swift value type, and stages through the common transaction. The native tool suspends until review and persistence finish; it returns the actual applied/rejected/error outcome. Once a proposal is staged, no further native tools may run in that turn. Cancellation releases the pending waiter; context recovery never replays a reviewed mutation. A successful edit invalidates the old snapshot/session after the response. The native `mutateCollection` adapter uses the same shared transaction and approval lifecycle. Resolve the collection and any existing member through the semantic read resolver; pass typed operations to `SBJStructuralCollectionMutation`. Use existing element factories for new members and follow with leaf mutations in later approved turns. Never reconstruct a collection from generated JSON. Count does not stage a proposal. An optional wrapper is addressed by explicit set/clearOptional operations; ordinary member operations target a present wrapped collection.

## 6. Context and verification

Favor concise instructions, compact grammars, small tool schemas, and narrowly scoped tool results. Measure actual native token usage and inference behavior rather than assuming that a more strongly typed schema or more compressed representation improves model performance.

Test exact key resolution, invalid paths, ambiguous and stale keys, collection negotiation, and exact emitted grammar text independently of model inference. Native tests should verify generated arguments and live model behavior on supported Apple platforms. Swift Testing availability belongs on individual tests or runtime guards, not `@Suite` declarations.

See [README.md](README.md) for the current implementation, tool registration, session lifecycle, and validation commands.

Collection member names are independent of member addressing. Explicit configured name hints can contribute a read-only optional synthetic name for a compound member without a declared name. No positional or value fallback is emitted as a synthetic name. Content selectors traverse only exposed scalar values and require exactly one matching member; all writes retain the shared transaction.
