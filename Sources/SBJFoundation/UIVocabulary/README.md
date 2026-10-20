# SBJUIVocabulary staging area (still in SBJFoundation)

These files remain in the **SBJFoundation target** while their API is settled. The sibling `Packages/SBJUIVocabulary` is an empty independent module scaffold.

Directories follow the proposed destination structure:
- `Appearance/` — candidate presentation primitives and supporting modifiers (individual dependencies still to be audited).
- `Buttons/` — candidate reusable semantic buttons; `SBJSymbolButton` now accepts only `SBJSymbol`.
- `Menus/` — candidate selection controls.
- `Fields/` — candidate text/numeric controls and their essential modifiers.
- `Search/` — the two reusable search UI files, not structural search logic.
- `Presentation/` — shared, lightweight helpers under consideration.

`OtherUI/` contains UI components not selected for the initial vocabulary package. `Color/` and `Font/` remain where they are until their editor- and layout-driven dependency closure is finalized. No UI type has been moved into `Packages/SBJUIVocabulary` yet.
