# SBJStructuredEditor — EditorSampleCoverage localization-related notes

### General UI vocabulary

- `ColorVariants` — application-facing color-source vocabulary used by SBJ applications.
  It remains intentionally valid outside the sample editor even though the sample does not
  require it. It is also an input to the presentation-resource/color design.
- `ImageReference` — **covered transitively by the sample editor** because editor button, status,
  and disclosure imagery now routes through the `ImageReference` boundary. It also remains
  general application-facing UI vocabulary.
- `SBJSelectionMenu` — collapse one-or-many actions into the appropriate toolbar/menu
  presentation.
- `NumberTextField` — **covered transitively by the sample editor** because
  `SBJIntegerEditor` uses it as the canonical reusable integer input. Range validity,
  locale formatting, chrome, sizing, and keyboard behavior therefore share one
  implementation; the structured editor adds its property label/accessibility and Stepper.
- `PendingAlert` / `Alertable` / `.pendingAlert(...)` — reusable alert state and
  view presentation; also a concrete input to the localization design.
- `URLText` — reusable read/display URL presentation. (`URLButton` itself is
  covered by the URL editor.)
- `AccessibleImage` / `AccessibleImageItem` — reusable image accessibility model.

