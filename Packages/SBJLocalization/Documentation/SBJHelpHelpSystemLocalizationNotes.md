# SBJHelp — HelpSystem localization-related notes

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

## Package boundary

The Help package depends only on SBJFileResources and SBJLocalization. It does not bundle any HTML help resources, and does not depend on SBJFoundation. URL opening is provided by SBJFileResources. App identity tokens are configured by callers in `applicationSubstitutions`. Foundation continues to provide its own bundled help references and an app-specific `SBJHelpConfiguration.foundation` preset.

