# Iteration 11 — Public assistant coordinator and factory

Based on the SBJStructuredAI package in the supplied `SBJFoundation(1).zip`. Update the app call sites along with this package. The package/module/product name, Swift tools version, deployment targets, and sibling dependencies remain unchanged. No changes to document models, native query parameters, prompts, path syntax, schema construction policy, model response handling, or token-budget policy are intended in this iteration. The previously observed HP query accuracy issue remains a separate experiment.

## Public host boundary

`SBJAssistantCoordinating` (Core/Conversation) describes host lifecycle, current-document availability, and feedback. `SBJAssistantPresenting` continues to describe conversation presentation. Neither protocol requires Foundation Models or exposes native session types. Apps can store the composition directly:

```swift
private var assistant: (any SBJAssistantCoordinating & SBJAssistantPresenting)?

assistant = SBJAIAvailability.makeAssistant(snapshot: { () -> SBJAssistantDocument<MyModel>? in
    // Return the current document snapshot, or nil.
    nil
})
```

`makeAssistant` is a main-actor, generic, read-only factory. It forwards optional instructions, diagnostic callback and error presentation to the internal `SBJAIAssistantCoordinator<Root>`. The root model type is inferred from the snapshot, not part of the returned protocol composition. The factory is declared on every package platform. It returns nil on unsupported SDK/OS/architecture combinations; on supported runtimes it creates a coordinator even if the model is disabled, preparing, or the device is not eligible, so presentation state remains authoritative. Creation does not read the snapshot, load a model, activate a conversation, or invoke persistence. Hosts should still use `SBJAIAvailability.isVisible` to decide whether to expose an assistant entry point.

The factory is now the supported public coordinator construction API. The concrete native coordinator is internal; native implementation tests use `@testable import`. `SBJAssistantView` accepts `any SBJAssistantPresenting` directly and retains generic header and input accessory view types only. No custom type-erasing adapter is needed, and Observation remains on the concrete assistant. The existing app-specific error wording and snapshot are passed by the host. No schema or query behavior changes.

## Package layout

- `Core/Conversation`: backend-independent document, message, state, shortcut, presentation contract, and transcript export.
- `Core/Feedback`: diagnostic categories, feedback events, and opt-in feedback collection.
- `Core/Semantics`: semantic snapshot, values, description, and structural change summaries.
- `AppleFoundationModel`: native session coordinator, availability mapping, dynamic schema builder, tool, and GeneratedContent conversion.
- `Presentation/AssistantView`: generic root view, composer, command field, transcript, message row, diagnostics, shortcuts, and options.
- `Presentation`: ancillary availability and feedback views, shared assistant nomenclature, and speech adapter.

Core has no direct SwiftUI or Foundation Models imports. Presentation has no Foundation Models imports or native AI type references. The coordinator supplies `availabilityState`, optional `availabilityProviderName` and optional `availabilityMessage(for:)` via `SBJAssistantPresenting`. The view does not inspect Apple Intelligence directly. Apple-specific availability guidance resides in `SBJAIAvailability`. That type remains usable on unsupported platforms and returns `.unsupported` there.

## Platform-specific presentation

The conversation is decomposed into independently type-checked SwiftUI views. Apple documents `ShareLink` as unavailable on tvOS and `roundedBorder` text field style as unavailable on tvOS/watchOS; both are conditionally excluded on those targets. Speech controls are only compiled on supported speech platforms, and the fallback controller has the same public operations. Text selection remains conditional on its platform availability. No view is conditionally excluded on account of Foundation Models. The generic view can be used with any conforming assistant.

Apple references:
- https://developer.apple.com/documentation/swiftui/sharelink
- https://developer.apple.com/documentation/swiftui/textfieldstyle/roundedborder
- https://developer.apple.com/documentation/swiftui/view/textselection(_:)
- https://developer.apple.com/documentation/swiftui/textfield/init(_:text:axis:)

## Migration

Use the public factory and protocol composition above in place of concrete coordinator references or app-specific type aliases. No deprecated aliases are supplied. Native schema inspection APIs retain their names. The read-only behavior and staged-change contracts are retained.

## Consolidation

The single shared transcript formatter uses speaker nomenclature and backend diagnostics; the separate discovery diagnostics property was redundant. The coordinator inherits the generic shortcut, persistence-state and default shortcut-selection implementations. Scalar raw values reuse the existing scalar adapter instead of a second conversion switch. The unused identity prompt wrapper was removed. The native schema and semantic snapshot remain separate because they describe different things (declared type definitions versus actual instance values).

The following sections document the preserved compact native-schema experiment.

## Complete schema versus session input

The complete instance-based native `DynamicGenerationSchema` still resolves into `GenerationSchema` using named dependencies. It retains all visible declared property types, human-readable titles, **details**, aliases, annotation constraints, unit metadata, enum alternatives, and the runtime access catalog (actual collection labels, counts, and active cases). It omits nomenclature `summary`, `accessibilityLabel`, and `accessibilityHint`. These omissions affect AI only, not the shared model metadata or accessibility elsewhere. The schema does not change the model or its serialization.

Repeated declarations use named references. Property titles are not repeated by the description builder. Native dictionary key/value constraints are described on their respective entry fields rather than duplicated on the parent. Associated-case descriptions occur once on the variant, not separately on its tag and payload. Undocumented simple enum cases are not repeated in narrative descriptions when already enumerated as schema choices.

The full native document schema is local, **not a generation constraint for the conversational answer**, and is not embedded in a tool parameter schema. A separate human-readable inspection description remains local for diagnostics and comparative measurements. Neither is appended to the prompt. A native schema describes what a model generates; it is not a mechanism for unbounded input context. The model sees concise developer instructions, one compact dynamic query schema, the actual user question, and the native tool results that it requests. This distinction is essential to keep ordinary conversational responses and document-specific questions viable.

## Native read-only tool

`readStructure` is registered using `Tool.parameters: GenerationSchema`; arguments and output are `GeneratedContent`. No document encoding, decoding, JSON transport, or model mutation. The parameter schema is independent of the number of paths in the instance. Exact access paths are validated against the immutable snapshot at execution, not enumerated as schema choices.

- `find`: `query` is a name, title, alias, description, or collection label. Exact names, titles and aliases rank ahead of partial matches. Uses SBJStructure's normalized text matching. Returns up to six compact address choices and the total count; refine the search if needed.
- `describe`: `paths` selects current fields and returns their full retained metadata, including details. No accessibility metadata or nomenclature summaries.
- `read`: `paths` selects actual values, including visible descendants; no generated or fabricated values.
- `count`: count of a present collection.
- `children`: one `paths` entry, optional zero-based `offset`, twelve immediate members per page; `totalChildren` and `nextOffset` distinguish complete and partial lists. Descriptions are retrieved through `describe`, not repeated for every child.

At most six paths per request. The live tool uses the native tokenizer when available and returns an explicit request for a narrower query if a result exceeds one quarter of the model context capacity. This is a per-result safeguard, not a complete cumulative transcript budget policy. Large single values are not silently truncated. Local snapshot access remains complete.

Addresses: `$` root; `/` separates components; escape `~` as `~0` and `/` as `~1`. Arrays use zero-based indexes; sets use snapshot-local selectors; dictionary entries use `key:<label>` or `entry:<ordinal>` followed by `/key` or `/value`. Associated enums expose `/caseName` and active `/payload/<field>`; absent optionals are native null, distinct from empty collections. Runtime labels need not be unique. Measurements retain amount and unit. Large exact integers and Decimal use numeric text if native Double would lose precision. Excluded fields are never exposed. Read-only computed fields remain readable.

## Diagnostics and lifecycle

On the first submission for a document revision, the coordinator uses Apple's native `SystemLanguageModel.tokenCount(for:)` to independently measure instructions (including any host-provided instructions), the compact query schema, registered tool including its parameter schema, the first question, the full local native document schema, and the local human-readable description. It reports `SystemLanguageModel.contextSize` rather than assuming the device has a fixed context capacity. These are independent counts, not additive: the registered tool count already includes the query schema. The full local document schema and text are **not** part of live model input. If any measurement fails, its error is reported without blocking other measurements or inference. Measurements are cleared on a document version change or deactivation. The native transcript and previous cancellation/stale-revision safeguards are preserved. Native context-overflow errors remain explicit; there is no automatic transcript compaction in this experiment.

## Inspection

```swift
let context = try SBJAISchemaBuilder.prepare(for: character)
let model = SystemLanguageModel.default
let fullSchemaTokens = try await model.tokenCount(for: context.documentSchema)
let querySchemaTokens = try await model.tokenCount(for: context.readParameters)
print(fullSchemaTokens, querySchemaTokens, model.contextSize)
```

`documentDescription` and `snapshot.instanceAccessDescription` remain local inspection data. A complete model is never reconstructed by the language model. No changes to host persistence callbacks or other foundation packages.

## Tests

The native-null, semantic metadata, alias ranking, duplicate item, child paging, native find and token-cost tests are retained. OS availability is on individual `@Test` functions and applicable helpers, never on suite declarations. Core feedback and nomenclature tests have no Foundation Models or OS-version guards; the debug-only sample remains guarded by `DEBUG` because the sample itself is conditional. Generic view-construction tests use a backend-independent test assistant and can compile without Foundation Models. Native tests remain guarded by their actual framework requirements. The portable suite ran 20 tests in six suites using Swift 6.2.1 and temporary Linux adaptations of the verified sibling packages; these adaptations are not shipped. Swift syntax parsing and ZIP integrity were checked. Native Foundation Models, SwiftUI and tvOS compilation, native token counts and on-device inference require Xcode verification.

## Apple documentation

- https://developer.apple.com/documentation/foundationmodels/dynamicgenerationschema
- https://developer.apple.com/documentation/foundationmodels/generationSchema
- https://developer.apple.com/documentation/foundationmodels/generatedcontent
- https://developer.apple.com/documentation/foundationmodels/tool
- https://developer.apple.com/documentation/foundationmodels/instructions
- https://developer.apple.com/documentation/foundationmodels/managing-the-context-window
- https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window
- https://developer.apple.com/documentation/testing/organizingtests

## Composer layout (Iteration 13)

The built-in top toolbar is removed. The composer displays feedback and transcript sharing before the text field, and microphone, speech output and send after the optional host input accessory. The existing options govern each control independently; the optional host header is unchanged. The draft remains private to the assistant view.

Simple command mode uses a multiline SwiftUI text field on keyboard-capable platforms. Unmodified hardware Return submits; Shift–Return uses native text selection to replace the selection with a newline on iOS 18/macOS 15/Mac Catalyst 18/visionOS 2 and newer. Older keyboard-capable targets delegate modified Return to the system multiline editor. tvOS and watchOS retain the original simple-command field. Multiline mode retains its existing editing behavior. Keyboard event delivery and focus must be verified on Apple platforms.
