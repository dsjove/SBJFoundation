# SBJStructure Accessibility & Localization Regression Checklist

The Recipe preview is the canonical visual/behavioral verification surface for the stock editor. Run this checklist before releases that materially change editor layout, control composition, metadata, formatting, identity, or focus behavior.

## Automated contract

Run the package tests. `SBJAccessibilityLocalizationRegressionTests` protects the parts of the contract that do not require a rendered accessibility tree:

- changed / no-content / invalid spoken state composition;
- stable Item Identifier vs changing Index Path;
- locale-aware human number and date formatting;
- constraint-informed sizing invariants across representative locales;
- locale-invariant UUID and hexadecimal technical representations.

## Preview matrix

Open `SBJStructuredEditorPreview.swift` and inspect all Recipe previews. In particular, verify:

- **Default** — baseline density and alignment.
- **Large Type** — controls grow without clipping.
- **Narrow + AX5** — rows reflow only when their enlarged intrinsic content cannot fit.
- **French / German** — numeric punctuation and control width remain usable.
- **Arabic RTL** — leading/trailing order mirrors correctly; hierarchy and trailing info remain coherent.
- **Changed Empty Invalid** — pencil, empty, and invalid treatments remain local to the represented row and do not disappear inside optionals or collections.
- **Dark** — semantic colors retain contrast.

## Xcode Environment Overrides / Accessibility Inspector

The following environment values are read-only in this target and must be tested with Xcode rather than injected into a preview:

- Increase Contrast
- Differentiate Without Color
- Reduce Transparency
- color filters

Verify that state remains understandable without relying on hue alone and that translucent decoration is not required for meaning.

## VoiceOver

With the Recipe editor visible:

1. Traverse from search through the editor in visual/structural order.
2. Verify a scalar is one meaningful stop (for example, “Servings”), not a visible label plus an anonymous duplicate control.
3. Change a value and confirm its spoken state includes “changed”.
4. Clear an optional and confirm “no content” is represented.
5. Create an invalid value and confirm “invalid” is represented.
6. Expand/collapse a disclosure and confirm Expanded/Collapsed state is announced.
7. Inspect a collection item, move it, and confirm it remains the same logical item after its position changes.
8. Verify Add, Remove, Move, Set/Clear, Info, and menu controls have understandable labels and actions.

## Keyboard / Full Keyboard Access

- Tab and Shift-Tab follow structural presentation order.
- Return/Space activates buttons and disclosures normally.
- Menus can be opened and selected with native keyboard behavior.
- Adding an optional or collection item gives useful focus-forward behavior.
- Reordering does not unexpectedly reset unrelated control focus.
- Filtering/search does not strand focus on a removed view.

## Switch Control

Verify that interactive elements appear in a sensible scan order and decorative dots, status glyphs, and chevrons do not become redundant targets.

## Acceptance rule

A visual difference is not automatically a regression. A release fails this checklist when content clips, becomes unreachable, loses semantic state, depends on color alone, uses culturally invariant punctuation for a human-facing value, reverses semantic leading/trailing behavior incorrectly, or changes logical identity merely because an item moved.
