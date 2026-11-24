# SBJHelp

`SBJHelp` presents help packaged with a SwiftUI application or feature package. It keeps resource lookup, content expansion, and presentation independent: the author supplies the content, while the library supplies help controls, the sheet, and format-specific presenters.

## Presenting help

```swift
import SwiftUI
import SBJHelp
import SBJFileResources

struct FeatureView: View {
    private let help = SBJBundledContentReference.help("Feature Overview")

    var body: some View {
        SBJHelpLink(asset: help, auto: false)
    }
}
```

Store `FeatureOverview.html` in your application's `help` resource directory (or supply a reference to a specific bundle). `SBJBundledContentReference` belongs to `SBJFileResources`, not SBJHelp. A missing resource omits the help trigger; an unreadable resource or unsupported format produces an unavailable-content sheet when presented directly.

**Controls:** `SBJHelpLink` uses the platform's ordinary help affordance, while `SBJHelpButton` deliberately uses a plain button in toolbars where system relocation matters. Both delegate sheet management to `SBJHelpTrigger`. Its `auto` option presents once per resource using shared UserDefaults; callers can set `auto: false` to disable first-use presentation. `SBJHelpSheet` may be presented directly when the host owns navigation.

## Configure shared content

```swift
var helpConfiguration = SBJHelpConfiguration.standard
helpConfiguration.addSymbolSet(MyAppSymbols.self)
helpConfiguration.addNomenclatureSet(MyAppNomenclature.self)
helpConfiguration.applicationSubstitutions["COMPANY_NAME"] = "Example Studio"
```

Pass the same configuration to your help controls to share the application's terminology. The configuration supplies an optional About resource, HTML stylesheet, application metadata, semantic images and nomenclature, as well as optional embedded help resources.

`SBJHelpTemplateRenderer` combines built-in, configuration, and per-presentation substitutions, with later values overriding earlier ones. Literal token matches use longest-match precedence and do not match inside larger identifier names; replacement text is inserted verbatim, not expanded repeatedly. Embedded resource content is rendered separately before insertion, allowing intentional document composition while preventing accidental token replacement within substituted values. Recursive embedding is stopped for repeated resource names. Unknown semantic tokens remain visible for diagnosis.

HTML documents can use `TITLE`, `DISPLAY_NAME`, `VERSION`, `COMPANY_NAME`, `EMAIL`, `URL`, `PRIVACY_URL`, `ICON` and `STYLE_SHEET`. Image tokens `SF_name\`, `AS_name\`, `UI_name\`, and nomenclature token `NOM_stable.id\` are expanded for HTML. Define your page using `<style>STYLE_SHEET</style>` to pick up the packaged shared stylesheet. Nomenclature definitions belong to `SBJLocalization`; the help renderer only presents them.

## Content formats and presenters

HTML is presented with WebKit when available. Native Markdown presentation requires the newer platform availability declared on `SBJMarkdownHelpPresenter` (iOS/macOS/Mac Catalyst/tvOS 27); older systems can still use HTML. To support another `UTType`, implement `SBJHelpContentPresenter`, then supply an `SBJAnyHelpContentPresenter` when showing the sheet or control. Unsupported content types do not silently render as HTML.

The package declares iOS 17, macOS 14, Mac Catalyst 17, visionOS 1, tvOS 17, and watchOS 10; individual presenters and controls have additional compile-time/platform restrictions. Help content is application-authored trusted HTML; WebKit opens activated http(s)/mailto links externally using `SBJFileResources` URL opening, with no change to that behavior in this iteration.

## Documentation

- [Help system and template reference](Documentation/HelpSystem.md)
- [Component responsibilities](Documentation/Architecture.md)

Future options include richer Markdown help and additional semantic content presenters. They are not part of the current contract.
