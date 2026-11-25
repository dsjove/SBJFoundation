# SBJStructuredAI — conversation reset

## Package structure

This is a complete replacement for the standalone package supplied in the prototype archive. It restores the conventional SwiftPM structure, Swift tools 6.4, original platform minimums and local `../SBJLocalization` dependency. There is no dependency on SBJStructure. Resolve dependencies afresh; the previous `Package.resolved` belonged to the removed dependency graph. Replace the package directory rather than merging source trees.

```
SBJStructuredAI/
  Package.swift
  README.md
  Sources/SBJStructuredAI/
    Coordinator/
    Presentation/
  Tests/SBJStructuredAITests/
    Coordinator/
    Presentation/
    Session/
```

The existing application integration and public API remain compatible. The app is not regenerated in this delivery. The current AI-specific OS 27 availability requirement is unchanged. The platform-independent visibility check remains callable on older systems. Unsupported architectures and Apple availability reasons are mapped to the existing unsupported, disabled, preparing, ready and unknown presentation states.

## Conversation

One native LanguageModelSession handles the conversation. Its initial instructions begin with `Query values of a structured data set` and explicitly explain that there is no connected data source. The existing generic document snapshot is only used for document presence and feedback revision. No character values are provided to the model. Mutation compatibility members remain inert. Successful conversation history is kept when a request fails or is stopped, while the failed or cancelled native session is discarded. Deactivation ends the conversation and releases its session. No new query semantics, schema, tools, structural traversal or persistence machinery are introduced.

## Prewarm

`SBJAIAssistantCoordinator.prewarm()` is a synchronous, nonthrowing MainActor operation. It can be called before activation, repeatedly, during an active conversation or while generation is running. It is a no-op if the model is not ready, a request is running, or a native session already exists. It creates and warms the exact session retained for the first submission (or a replacement session after cancellation/failure), with the same instructions and any completed transcript. It does not activate the coordinator, submit a prompt, or modify messages. `deactivate()` also releases a session warmed before activation. It does not guarantee that Apple has completed prewarming. Calls on the coordinator must still be within its existing OS availability boundary; on earlier systems the coordinator does not exist.

Recommended application call site: `EditorCoordinator.assistant(for:)`, inside its existing `visibleEditor == .assistant` branch, after `instance.activate()`. The user opening the Assistant is a strong signal that they may type a request shortly. Repeated SwiftUI construction is harmless because the coordinator only warms a new session. If the model is preparing when opened, retry when the Assistant availability transitions to ready or the input receives focus. Do not warm at application startup, on every character load, or immediately before `submit()`; Apple recommends at least one second of useful lead time. Do not delay a user's submission to obtain that lead time. No speculative prompt prefix is passed.

```swift
if visibleEditor == .assistant {
    instance.activate()
    instance.prewarm()
}
```

Apple references:
- https://developer.apple.com/documentation/foundationmodels/languagemodelsession/prewarm(promptprefix:)
- https://developer.apple.com/documentation/foundationmodels/optimizing-key-value-caching-in-language-model-sessions

## Tests

- `Presentation/SBJAIAssistantAvailabilityTests`: retains policy, mapping and view tests; adds the five-state prewarm policy matrix (existing-session and busy guards).
- `Presentation/SBJAIAssistantFeedbackTests`: recovered both prototype tests, updating the opt-in example from a rejected proposal to a stopped request. Correction classification remains tested for compatibility.
- `Presentation/SBJAIAssistantNomenclatureTests`: recovered both prototype tests unchanged.
- `Coordinator/SBJAIAssistantCoordinatorTests`: retains reset compatibility and guards; restores the initial-state lifecycle intent of the prototype and adds unavailable prewarm coverage (no native loading on ready devices during routine unit tests).
- `Session/SBJAIConversationContinuityLiveTests`: replaces the old intent/grounding follow-up assertions with a native two-turn conversation smoke test and fresh activation check. The suite is serialized and opt-in with `SBJ_RUN_LIVE_CONTINUITY_TESTS=1`. It requires a ready model, waits for actual request completion with a bounded timeout, and checks recall of a supplied fact rather than exact prose. By default it deliberately gives prewarm two seconds of lead time; set `SBJ_PREWARM_LIVE_TESTS=0` to run without the hint or delay. It is not a latency benchmark.

The remaining prototype tests (Structure, Editing, Grounding, Intent, persistence and custom semantic context/hardening) target intentionally deleted implementations. They were not moved into the active test target; keep them on the reference branch for future query experiments. Unit tests should not load the model. For future live suites, prepare a retained session while doing independent fixture setup when there is real lead time, rather than adding sleeps to every test. Keep independent cases isolated and serialize real model tests where they would contend. Profile cold and warm runs separately, with equivalent prompts/session state; do not impose an absolute latency expectation in correctness tests.

## Schema inclusion

The current `respond(to:)` is text-only, so no `includeSchemaInPrompt` option applies. Do not add a schema solely to optimize its inclusion. When experimenting with guided generation, include the schema on the first request for a particular response type in each new session. Consider `includeSchemaInPrompt: false` on later requests using the same schema when the transcript still supplies adequate context, or with exhaustive examples in instructions. Optional fields need examples of both presence and absence; schema guide descriptions are not supplied when omitted. If the schema changes or context is rebuilt without it, include it again. Treat omission as an optimization, not a semantic choice. Compare output correctness and token use with Instruments before adopting it. Independent fresh-session tests should normally retain schema inclusion; test the omission variant explicitly.

Apple references:
- https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app
- https://developer.apple.com/videos/play/wwdc2025/259/

## Validation

Six portable Swift Testing tests (including a parameterized five-state policy test) passed in a temporary Swift 6.2.1 Linux harness. All package source and test files passed Swift frontend syntax parsing. The delivered manifest restores Swift tools 6.4; the local toolchain is 6.2.1 and cannot validate that manifest directly. A temporary copy with its tools-version lowered to 6.2 passed `swift package dump-package`; that does not validate 6.4. The sibling SBJLocalization package and Apple SDKs are not provided. Full package compilation, Apple-only tests, actual prewarming, and native responses remain unverified in this environment. Run them in Xcode on Apple hardware.
