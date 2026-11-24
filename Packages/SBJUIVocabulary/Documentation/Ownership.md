# UI Vocabulary: API ownership and design boundaries

This document explains the current intended public API surface for clients and notes possible future work. It is not a migration history.

## Inclusion rule

A component belongs in `SBJUIVocabulary` when it expresses a **general SwiftUI presentation pattern** reusable across unrelated features: a common action, selection policy, input configuration, shared visual state, or a small platform-specific bridge for a foundational value type. Being implemented in SwiftUI is not, by itself, sufficient.

Keep help content/presentation, document persistence and synchronization, structural editors, and AI assistant workflows in their owning packages. Native share/export/preview presentation is a deliberate coherent feature family inside `Sharing`, not a precedent for bringing arbitrary application workflows here.

## Action controls

`SBJAddButton`, `SBJApplyButton`, `SBJDeleteButton`, `SBJRemoveButton`, `SBJDismissButton`, and move buttons are named UI actions. `SBJSymbolButton` and `SBJNomenclatureButton` provide the general underlying presentation. Preserve deletion/confirmation versus removal semantics; combining the two buttons would hide a meaningful user-interaction distinction.

Any future language-aware action phrases should use complete localizable resources rather than independently translating a verb and noun and concatenating them. This is future design work, not the current contract.

## Contextual presentation

Presentation suppression for share-sheet workflows lives under `Sharing/Presentation`, alongside the share presenter and host. It should not be repurposed as a general workflow environment contract.

## Foundation model adapters

`CodableColor`, `CodableFont`, and domain units stay in `SBJStructure`. Their SwiftUI editing and rendering adapters remain here. `SBJLocalization` continues to own meaning, symbolic identity, and accessibility concepts.

## Specialized controls and future direction

The existing `AttachmentsView` owns import, rename, preview, and removal interactions. This makes it more substantial than a primitive input control. It is retained for source compatibility, but additional attachment business logic should not be added to Vocabulary by default. The `Sharing/Documents` document preview now reuses `AttachmentPreviewSheet`, consolidating Quick Look bridging while preserving the two separate public view APIs. Review attachment-editor ownership only if a clearly defined alternative package emerges.

Potential future improvements include locale/font-aware field sizing, clearer presentation-resource localization for action labels, and a dedicated attachment UI boundary. None should require structural metadata to define ordinary UI semantics.
