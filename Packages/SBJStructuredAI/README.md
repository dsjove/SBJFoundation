# SBJStructuredAI — UI-only stub

This is an intentionally minimal reset of SBJStructuredAI. It preserves the API
used by the existing Jove’s Characters assistant coordinator and retains the
reusable `SBJAIAssistantView` SwiftUI chat view.

## Included
- `SBJAIConversation<Root>`: `init`, `model`, `revision`, `send`, `approve`,
  `reject`, `replaceModel`, `diagnoseTargets`, `discoveryDiagnostics`, `isAvailable`.
- The conversation-event and approval-summary types needed by the app's
  coordinator and the view.
- `SBJAIAssistantMessage`, `SBJAIAssistantLabels`,
  `SBJAIAssistantPresenting`, and `SBJAIAssistantView`.

## Deliberately omitted
No FoundationModels import, native model session, search, intent routing,
semantic field catalog, discovery, mutation, proposal creation, or diagnostic
engine. This package never edits or reads document values. The `send` method
returns a visible stub response; `approve`/`reject` reject nonexistent proposals.

The application coordinator and SwiftUI view can remain in place. The
coordinator's optional diagnostic call simply receives `[]`.

**Compatibility scope:** the public surface called by the current
`CharacterAssistantCoordinator.swift` and `CharacterAssistantView.swift`.
Other former public semantic APIs have been intentionally removed.

**Verification:** syntax parsing on the available Linux Swift compiler;
Xcode/macOS/Catalyst compilation is not available here.
