# SBJStructuredAI Architectural Rules

These rules govern model communication, semantic resolution, tool implementation, and future mutation support. They apply to all contributors and should be consulted before changing the assistant architecture.

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

## 3. Deterministic addressing

Use root-relative key paths. A structural key is the numeric declaration ID supplied in the static document definition. A collection key is an exact member key supplied by a tool, or a supplied one-based `@n` array position. Template references expose their declared members transparently; template numbers and the implicit root are not path components.

Resolve keys sequentially against the current node. Do not infer an intended field or member from an approximate name or from the user's question. Titles and aliases guide the model's selection; they are not alternative structural field keys. A collection display title may be used as a key only where the collection's explicit addressing contract permits it and it uniquely resolves. Prefer returning the canonical selectable key alongside any differing display title.

For example, the AI interprets “What is Pebble's HP?”, obtains the relevant collection keys, selects `Pebble`, and generates:

```swift
["3", "42", "Pebble", "45", "47", "49"]
```

Swift traverses those keys without interpreting the question. IDs in this example are illustrative document declarations, not hardcoded business-domain rules.

## 4. On-demand collection negotiation

Keep the static structural catalog separate from live collection membership and values. Do not inject a complete live collection index into every prompt or into the session instructions. The model requests relevant keys through `readKeys`, or receives keys when `readValue` reaches an unresolved collection member. The model selects the key using natural-language reasoning and supplies the completed path.

Return only relevant keys, with deterministic ordinal alternatives where necessary. Never silently choose among ambiguous matches. Invalid or stale keys produce explicit failures or actionable negotiation results; the model decides how to proceed. No global runtime instance IDs or separate scope argument are needed.

## 5. Validation and execution

Validate paths, member identity, optional presence, active enum payloads, applicable constraints, and business rules in Swift. Keep unset, empty, inactive, missing, ambiguous, and invalid conditions distinguishable. Never invent values, silently truncate results, or silently substitute a different member.

Use typed semantic results internally and render them at the model-facing boundary. Keep platform-independent semantic logic separate from Apple Foundation Models integration. Preserve the public coordinator boundary and avoid speculative compatibility adapters.

## 6. Future mutations

These same rules apply to mutation tools. The AI interprets the requested change and produces native generated arguments. Swift resolves supplied keys against the current snapshot, validates permissions and business rules, and executes the change deterministically. Do not infer a mutation target or operation from natural-language text inside a tool.

Collection membership and names may change. Resolve and validate keys against the current document revision, and make stale or ambiguous targets explicit rather than guessing. Structural definitions remain separate from live values and membership.

Mutation support is a future capability, not a claim about the current read-only implementation.

## 7. Context and verification

Favor concise instructions, compact grammars, small tool schemas, and narrowly scoped tool results. Measure actual native token usage and inference behavior rather than assuming that a more strongly typed schema or more compressed representation improves model performance.

Test exact key resolution, invalid paths, ambiguous and stale keys, collection negotiation, and exact emitted grammar text independently of model inference. Native tests should verify generated arguments and live model behavior on supported Apple platforms. Swift Testing availability belongs on individual tests or runtime guards, not `@Suite` declarations.

See [README.md](README.md) for the current implementation, tool registration, session lifecycle, and validation commands.
