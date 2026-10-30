# Help System

SBJHelp owns the reusable Help presentation and rendering system. Applications provide their own help resources and application-specific token values; SBJFoundation integrates its feature-specific Help pages.

## Design goals

- Preserve the existing asset-catalog HTML help authored by SBJ applications.
- Preserve the historical template-token contract, including application metadata and embedded
  SF Symbol/application-asset images.
- Treat About as a help resource and keep its entry point in the help presentation toolbar.
- Use Apple's semantic content-type system rather than a parallel help-format enumeration.
- Keep the sheet/chrome independent of the content presenter so new formats can be added later.
- Use native SwiftUI help UI when the target SDK provides it, while retaining the same behavior on
  iOS and Mac Catalyst where `SwiftUI.HelpLink` is unavailable.
- Resolve semantic symbols through SBJLocalization, allowing callers to configure additional imagery.

## Source organization

`SBJBundledContentReference` lives with the Foundation/resource support and is the generic reference/loading boundary for asset-catalog data sets and ordinary bundle resources.

`SBJBundledContentReference` itself lives in SBJFileResources; `Packages/SBJHelp/Sources/SBJHelp/` contains:

- `SBJHelpTemplateRenderer` — standard and caller token expansion.
- `SBJHelpContentPresenter` / `SBJAnyHelpContentPresenter` — format-specific presentation boundary.
- `SBJHTMLHelpPresenter` — WebKit presentation for existing HTML help.
- `SBJMarkdownHelpPresenter` — native SwiftUI presentation for Markdown help.
- `SBJHelpSheet` — shared navigation chrome, About entry point, and presenter dispatch.
- `SBJHelpTrigger` — sheet and first-use presentation behavior.
- `SBJHelpLink` — standard entry control for new application code.
- `SBJHelpConfiguration` — application metadata, About/style resources, and shared substitutions.

## Content types

Help formats are identified by `UniformTypeIdentifiers.UTType`; SBJHelp does not define a
parallel `SBJHelpFormat` enumeration or identifier namespace.

`SBJBundledContentReference` is the generic reference for both asset-catalog data sets and ordinary bundle
resources. It carries a `displayName` because resources outside the help system also need a
human-readable presentation name. For bundle resources, `resourceName` is optional: when omitted,
it is derived from `displayName` with `String.sanitizedFilename(removeSpaces: true)`. This keeps the
visible name and default filename convention in one place while still allowing an explicit resource
name when they intentionally differ.

```swift
let html = SBJBundledContentReference(
    displayName: "Recipe Details",
    subdirectory: "help"
)

let catalogData = SBJBundledContentReference(
    displayName: "Recipe Details",
    dataAsset: "help/RecipeDetails",
    contentType: .html
)
```

For asset-catalog data sets, the content type normally comes from `NSDataAsset.typeIdentifier`; an
explicit type overrides it. For bundle resources, the type is inferred from the filename extension
unless explicitly overridden.

HTML help uses the standard `SBJBundledContentReference.help(...)` factory, which supplies the `html` extension,
the lowercase `help` source subdirectory, and `.main` bundle. Application call sites normally need
only the display name; the sanitized display name becomes the resource filename automatically.

## Framework-bundled and embedded help

Structured-editor help resources are bundled with `SBJStructuredEditor`, not SBJFoundation or SBJHelp. Import the editor module and call `SBJHelpConfiguration.includeStructuredEditorHelp()` when configuring application Help. It registers the editor-owned `.structuredEditorCore` and `.structuredEditorSearch` bundled-content references for the two embedded HTML tokens.


## Presenter dispatch and extension

The built-in presenter registry supports HTML and Markdown. Presenter selection uses the asset's
resolved `UTType`; a presenter may also be supplied explicitly.

A future format does not require a change to `SBJBundledContentReference` or `SBJHelpSheet`. Define or obtain an
appropriate `UTType`, conform a presenter to `SBJHelpContentPresenter`, and pass its type-erased
form where help is presented.

```swift
struct PlainTextHelpPresenter: SBJHelpContentPresenter {
    let contentType: UTType = .plainText

    @MainActor
    func makeView(source: String) -> AnyView {
        AnyView(ScrollView { Text(source).padding() })
    }
}
```

This boundary is intentionally representation-focused: shared navigation, About, automatic
first-use behavior, and token expansion do not belong to individual presenters.

## HTML help and template tokens

HTML remains a first-class format because existing applications have substantial authored content.
`SBJHTMLHelpPresenter` uses `WKWebView`; there is no requirement to rewrite existing help.

`SBJHelpTemplateRenderer` preserves the established substitutions:

- `TITLE`
- `DISPLAY_NAME`
- `VERSION`
- `COMPANY_NAME`
- `EMAIL`
- `ICON`
- `STYLE_SHEET`
- `SF_<symbol>\\` for SF Symbol images
- `AS_<asset>\\` for application asset images

Configuration substitutions are applied after standard substitutions, and per-presentation caller
substitutions are applied last. Later values therefore override earlier values.

SF Symbol and application-asset token rasterization remains HTML-renderer work because those
values become embedded image data inside the HTML document. UI controls surrounding the document
do not hard-code symbol strings; they use `SBJSymbology`.

## Markdown help

Markdown data assets use `SBJMarkdownHelpPresenter`. Template substitutions occur before Markdown
parsing, so standard and caller tokens work for Markdown as well as HTML. The presenter converts
the expanded source to `AttributedString` and displays it in a native SwiftUI scroll view.

Markdown is additive. It does not replace HTML and does not change the legacy asset convention.

## Help entry control and Mac Catalyst

`SBJHelpLink` is the semantic help entry point for new code. It always routes into the same
SBJFoundation trigger, sheet, and presenter pipeline.

Where `SwiftUI.HelpLink` is available, `SBJHelpLink` uses it. The SwiftUI API is explicitly
unavailable in the iOS SDK, and Mac Catalyst compiles against that SDK surface. On iOS and Catalyst,
`SBJHelpLink` therefore uses an `SBJSymbolButton` with `SBJHelpSymbology.help` as the
platform fallback. This is a presentation fallback only; help behavior and content are identical.

The platform conditional must remain compile-time. Referencing `SwiftUI.HelpLink` in an iOS or
Catalyst code path is a compile error even if guarded only by a runtime availability check.

`SBJHelpToolbarButton` is the toolbar-placement variant. It intentionally renders a plain SwiftUI
`Button`/`Label` rather than `HelpLink` or `SBJSymbolButton`, so SwiftUI can collapse and relocate the
item as ordinary system toolbar content (including horizontal-to-vertical toolbar transitions). It
uses the same `SBJHelpTrigger` and `SBJHelpSheet` pipeline; only the visible control differs.

## Shared UI vocabulary

Help-owned UI symbols are semantic entries in `SBJSymbology`, including Help, About,
Dismiss, unavailable/unsupported help, page down, and scroll-to-top. Help views consume those
references through `Image`, `Label`, or `SBJSymbolButton` rather than embedding raw SF Symbol names.

The HTML `SF_...\\` token mechanism is intentionally different: those symbol names are authored
content embedded in existing HTML and are resolved by the HTML template renderer.

## About

About is a help resource, not a separate application workflow. `SBJHelpConfiguration.aboutAsset`
defaults to the `help/About.html` bundle resource and uses the same lookup, token expansion, presenter, and
sheet implementation as ordinary help. When present, About appears in the help sheet toolbar.

This convention deliberately gives every application a consistent location for About/version/
support information without requiring each app to allocate another navigation destination.

## Automatic first-use presentation

`SBJHelpTrigger` preserves the legacy `auto` behavior. Presentation history is keyed by the help
asset's stable `fullName` and stored in `UserDefaults`. About can independently use the same
mechanism through `SBJHelpConfiguration.autoPresentAbout`.

## Testing contract

`Tests/SBJFoundationTests/Help/SBJHelpTests.swift` protects the semantic boundary rather than
snapshotting Apple UI. It verifies:

- filename-extension to `UTType` resolution;
- explicit content-type precedence over an asset catalog identifier;
- asset-catalog type-identifier resolution;
- default bundle-resource filenames derived from `displayName` with `sanitizedFilename(removeSpaces: true)`;
- Foundation bundle-resource loading and content-type inference;
- bundled structure-editor-core and structure-editor-search help availability;
- recursive embedded-help expansion;
- built-in HTML/Markdown presenter selection;
- construction of `SBJHelpLink(asset:)` on the current target (important for Catalyst compilation);
- use of shared semantic image references for Help UI.

Apple's own `HelpLink`, WebKit, and SwiftUI rendering behavior are not duplicated in unit tests.

## Semantic image tokens

HTML help can use `UI_name\` tokens for controls that are part of the shared UI vocabulary. For example, `UI_help\`, `UI_restore\`, `UI_add\`, and `UI_moveUp\` render the same imagery used by the SwiftUI controls. Applications may add or replace entries through `SBJHelpConfiguration.semanticImages`. Raw `SF_symbol.name\` and `AS_assetName\` tokens remain available for help-specific imagery.

## Bundled Foundation help

Editor-specific HTML resources belong to `SBJStructuredEditor`. Its view-level `help()` methods provide the supported entry points.


## Resource directory layout

Source resources are organized into `Resources/help`, but runtime lookup must not rely on that directory surviving resource processing. SwiftPM `.process` recursively processes files and places otherwise-unprocessed outputs at the resource bundle top level; preserving a directory hierarchy requires `.copy`. Xcode bundle-resource processing similarly guarantees placement in the bundle resource area, not the source-tree group hierarchy. `SBJBundledContentReference` therefore tries the authored subdirectory first and the bundle root second.

## Package boundary

The Help package depends only on SBJFileResources and SBJLocalization. It does not bundle any HTML help resources, and does not depend on SBJFoundation. URL opening is provided by SBJFileResources. App identity tokens are configured by callers in `applicationSubstitutions`. Foundation continues to provide its own bundled help references and an app-specific `SBJHelpConfiguration.foundation` preset.
