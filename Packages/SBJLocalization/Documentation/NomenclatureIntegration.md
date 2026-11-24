# Nomenclature, symbology, accessibility, and help

## Status and scope

This documents the implemented APIs in the iteration 26 source snapshot. `SBJNomenclature` is declaration-site user-facing vocabulary, not a model mutability policy and not a runtime accessibility value. `SBJSymbology`/`SBJSymbol` provide semantic imagery. Consumers (SwiftUI, the structured editor, reports, and HTML help) decide how the shared declarations are presented.

The refactor is designed to have **one authoritative definition for each concept**, not one universal label for unrelated actions that happen to share a verb. For example, removing an attachment and removing a section may warrant separate nomenclature entries. Static user-facing names and explanations belong in their owning module; selected values, filenames, validation failures, and state-dependent details remain at runtime.

## The canonical value

`SBJNomenclature` is defined in `SBJLocalization` and currently contains:

| Field | Role |
| --- | --- |
| `title: String?` | Display name of the concept/action |
| `summary: String?` | Brief explanation; fallback accessibility hint |
| `details: String?` | Canonical longer explanation, including usage instructions |
| `aliases: [String]` | Alternate searchable names for semantic discovery |
| `symbol: SBJSymbol?` | Semantic symbol associated with the definition |
| `accessibilityLabel: String?` | Optional spoken-label override |
| `accessibilityHint: String?` | Optional spoken-hint override |

There is **no `help` field**: `details` is the single source of longer-form help. There is **no** `.labeledSymbol` conversion property in this snapshot. The computed `.accessibility` returns `AccessibleItem(label: accessibilityLabel ?? title, hint: accessibilityHint ?? summary)`. It deliberately does not speak `details` as a default hint.

A representative declaration:

```swift
import SBJLocalization

let example = SBJNomenclature(
    title: "Restore attachment",
    summary: "Restores a previously removed attachment",
    details: "Returns the attachment to the editable collection.",
    symbol: /* domain SBJSymbol definition */ nil
)
```

The example does not prescribe a new symbol name. Reuse the owning package's `SBJSymbol` instead of introducing raw SF Symbol strings at individual call sites.

## Stable keys and ownership

`SBJNomenclatureSet` is `@dynamicMemberLookup` and exposes `static var all: [String: SBJNomenclature]`. Swift UI callers use dot syntax, such as `SBJImageNomenclature.imageEnhancementReset`, rather than dictionary subscripts. The canonical dictionary keys (for example `image.enhancement.reset`) remain unchanged for help tags and localization. The dynamic member lookup normalizes punctuation and capitalization; it requires exactly one matching key and traps for missing or ambiguous names. Keep keys distinct after normalization. `all` remains available for help registration and enumeration. The keys are **stable, nonlocalized identifiers**, not titles or SF Symbol names. Declare them once in the owning feature/package. Shared concepts belong in shared sets such as `SBJCommonNomenclature`; distinct contextual actions belong to domain sets. Avoid duplicate literal keys: dictionary merging can silently override a previous entry.

When a UI needs an existing definition, reference the same set and key used by help. Do not copy its title, symbol, summary, or details to a separate label/accessible-item constant. Prefer direct nomenclature-aware controls, e.g. the provided `Label` initializer, over redundant conversion wrappers. A consumer may add runtime context (such as a field name or state) without altering the underlying definition.

Data Definition macros and lookups refer to **nomenclature** rather than the previous `SBJPropertyInfo` terminology. See the Data Definition structural metadata contracts for `@SBJStructure`, `@SBJNomenclature`, property lookup, extension fallback, and enum-case lookup. These are distinct from structural mutation permissions and explicit invariants.

## Accessibility

Static identity and guidance originate from `SBJNomenclature.accessibility`. Apply the project's accessibility view modifier or nomenclature-aware control where suitable; preserve SwiftUI traits, values, dynamic hints, selection state, grouping, and interaction semantics in the view. Accessibility values must never be frozen into the declaration metadata. Not every plain-text runtime message needs a nomenclature definition.

## HTML help

A complete control/action entry in help is authored as a standalone token:

```html
NOM_restoreAttachment\
```

The token's ID must match a registered `SBJNomenclatureSet` key (the ID above is illustrative, not a guarantee that such a key exists in every application). The HTML file must not repeat the action explanation beside the token. Higher-level workflows and conceptual documentation remain ordinary HTML prose. Use `UI_<id>\` only for decorative/reference-only imagery without an appropriate nomenclature entry.

Register the owning set in the configuration passed to the help renderer:

```swift
var configuration = SBJHelpConfiguration.standard
configuration.addNomenclatureSet(MyFeatureNomenclature.self)
```

The configuration includes common/help nomenclature by default; embedded help from other packages requires the corresponding sets to be registered. `addNomenclatureSet(_:)` merges keys, with later values taking precedence, so collisions are design defects rather than a localization mechanism. Unknown `NOM_` references remain visible to expose registration errors.

## Shared stylesheet

Every full help document loads the `SBJHelp` stylesheet via `<style>STYLE_SHEET</style>`. The canonical CSS is `SBJHelp/Sources/SBJHelp/Resources/Help.css`. The renderer creates the semantic `sbj-nomenclature` section, heading, title, summary, and details elements. Keep typography, spacing, and responsive/light-dark presentation in this shared stylesheet—not in a nomenclature string or app-specific HTML block. Partial embedded help fragments intentionally inherit their host document's stylesheet. `styleSheetAsset` remains an optional exceptional additional CSS input; it is **not** an invitation for each app to maintain a competing design.

## Localization and reporting

Current nomenclature fields contain `String` values. Stable IDs allow callers and HTML templates to remain independent of translated display wording, but a complete resource-backed locale resolver is still described as *future work* in the localization design documents. Do not claim the current implementation automatically translates these strings.

`SBJDataDefinitionReport` is another consumer: it uses the same property and enum-case `summary`, `details`, and `symbol` when reporting those concepts, while intentionally omitting accessibility overrides. Reporting policy/visibility annotations remain a separate concern from nomenclature. Neither report formatting nor editor choices should create duplicate prose.

## Checks and integration limitations

The portable integration checker in this snapshot validates HTML nomenclature references, registration patterns, and stylesheet usage. Syntax parsing does not establish type correctness, Swift macro expansion, app target linkage, runtime HTML rendering, or VoiceOver behavior. The full Xcode build and applicable runtime tests must still be performed on a compatible macOS toolchain.

## Authoring checklist

1. Search for a shared/domain definition before declaring a new concept.
2. Create one context-appropriate stable key with title, summary, canonical details, and semantic symbol as needed.
3. Use it directly in the control and for static accessibility defaults; add runtime values only at the view.
4. Register the owning nomenclature set wherever a help page or embedded help references its key.
5. Replace duplicated HTML action descriptions with a standalone `NOM_...\` token; leave ordinary workflow prose intact.
6. Keep HTML styling in `SBJHelp/Resources/Help.css`.
7. Check duplicate keys, unresolved tokens, package dependencies, and Xcode/VoiceOver behavior before a release.
