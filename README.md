# Source ownership and API correction

Apply these files relative to `SBJFoundation/` in the latest consolidated source tree and remove every path in DELETE_PATHS.txt. This is a source patch, not a verified Xcode build.

- `SBJStructuralSearchCriteria` and its behavior tests moved from editor to DataDefinition; editor consumers import DataDefinition directly.
- `UnitNumberFormat` renamed to `SBJNumberFormatStyle` in Localization, with all uses updated. No deprecated alias.
- `PackageAttachmentStoreTests` no longer imports SBJUIVocabulary or SBJDataDefinition: it exercises Foundation's store and SBJFileResources' content types.
- Added Help's own standard-configuration embedded-image test using the existing test fixture. The existing Foundation-specific `.foundation` configuration integration test intentionally remains with its implementation: `.foundation` is defined in SBJFoundation and depends on Foundation AppInfo. Moving *that exact test* to SBJHelp would introduce a reverse dependency, unlike moving the generic rendering test.
- Editor-owned macro expansion and unit editor integration tests remain in StructuredEditor, even though their fixtures involve DataDefinition types.

Test human-readable output equivalence and imports across every file still require a separate exhaustive source-level review: this patch does not claim those are complete. Swift/Xcode builds have not been executed.

## Image package

Image functionality is now owned by `Packages/SBJImage`. Clients importing image APIs directly should `import SBJImage`; SBJFoundation depends on it for the `Bundle.icon` extension.


Page-layout editing (`PageLayoutEditorCore` and `PageLayoutEditorView`) lives in the umbrella `SBJFoundation` module. `PageLayout`, `PageSize`, and `Insets` are structural models in `SBJLayout` and do not depend on `SBJStructuredEditor`.
